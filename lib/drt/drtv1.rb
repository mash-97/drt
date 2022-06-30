# frozen_string_literal: true

require 'logger'
require 'yaml'
require 'faraday'
require 'active_record'

require_relative 'key_maps'
require_relative 'migrator'
require_relative 'models'

# DIU student Result Trends
module DRT1
  # module to maintain structure
  DRT_DIRPATH = File.join(ENV['HOME'], '.drt')
  DRT_CONFIGPATH = File.join(DRT_DIRPATH, 'drt_config.yml')
  DRT_LOGPATH = -> { File.join(DRT_DIRPATH, "drt__#{Time.now.strftime('%d_%m_%Y__%H_%M_%S')}.log") }

  DEFAULT_DB_PATH = File.join(DRT_DIRPATH, 'drt.db')
  DEFAULT_DB_LOG_PATH = File.join(DRT_DIRPATH, 'drt_db.log')

  class LogDev < Logger::LogDevice
    def write(data, &puts_lambda)
      super(data)
      data = puts_lambda if puts_lambda
      puts(data)
    end
  end

  LOGGER_GEN = lambda do |log_path = DRT_LOGPATH.call()|
    l = Logger.new(LogDev(log_path))
    l.formatter = proc do |severity, datetime, progname, msg|
      datetime = datetime.strftime('%d-%m-%Y %H:%M:%S')
      if progname
        "[#{datetime}]: (#{severity}) (#{progname}) => #{msg}\n"
      else
        "[#{datetime}]: (#{severity}) => #{msg}\n"
      end
    end
    l
  end

  SITE_URL = 'http://software.diu.edu.bd:8189'
  FARADAY_CONNECTION_GEN = lambda do
    Faraday.new(
      url: SITE_URL,
      headers: {
        'Content-Type' => 'application/json'
      }
    ) do |faraday|
      faraday.request :json
      faraday.response :json
    end
  end

  DB_CONNECTION_GEN = lambda do |db_path, logger|
    ActiveRecord::Base.establish_connection(
      adapter: :sqlite3,
      database: db_path,

      logger: (if logger.instance_of?(String)
                 Logger.new(logger)
               else
                 (log_path.instance_of?(Logger) ? logger : nil)
               end)
    )
  end

  ## Exceptions
  # Student NULL if student info not found
  class StudentNull < StandardError
    def initialize(student_id = nil, exception = nil)
      super("Student (#{student_id}) not found!\n--> exception: #{exception}")
    end
  end

  # Semester NULL if semester_id with given student_id not exists
  class SemesterNull < StandardError
    def initialize(student_id = nil, semester_id = nil, exception = nil)
      super("Semester (#{semester_id}) with student (#{student_id}) not exists!\n--> exception: #{exception}")
    end
  end

  ##
  # Config class
  class Config
    # attributes to maintain configuration static
    attr_accessor :db_path, :db_log_path

    def initialize(config_path, db_path, db_log_path)
      @config_path = config_path
      @db_path = db_path
      @db_log_path = db_log_path

      reconfig unless File.exist?(@config_path)

      @configs = Config.load_configs(@config_path)
      @db_path, @db_log_path = Config.parse_configs(@configs)
    end

    def reconfig
      Config.initialize_config(@config_path, @db_path, @db_log_path)
    end

    def self.parse_configs(configs_hash)
      db_path = configs_hash['db_path']
      db_log_path = configs_hash['db_log_path']
      [db_path, db_log_path]
    end

    def self.load_configs(config_path)
      YAML.load_file(config_path)
    end

    def self.initialize_config(config_file_path, db_path, db_log_path)
      configs = {
        'db_path' => db_path,
        'db_log_path' => db_log_path
      }
      File.open(config_file_path, 'w+') { |f| YAML.dump(configs, f) }
    end
  end

  ##
  # DIU student Result Trends Class
  class DRT
    ##
    # This class does the heavy work
    attr_accessor :config
    attr_accessor :logger, :db, :faraday_connection

    def initialize(config, logger = LOGGER_GEN.call())
      @faraday_connection = FARADAY_CONNECTION_GEN.call
      @config = config
      @logger = logger
      @db = DB_CONNECTION_GEN.call(@config.db_path, @config.db_log_path)
      unless @db.connection.table_exists?(:students) || @db.connection.table_exists?(:semester_results)
        DRTMigrator.migrate(:up)
      end
    end
  end

  # get student info by calling faraday connection
  # returns nil if not found
  # returns parsed student data if found
  # will throw exceptions if any problem faced during connection call
  def self.get_student_info(student_id, logger = nil, faraday_connection = FARADAY_CONNECTION_GEN.call())
    logger.info("(get_student_info:request) #{student_id}") if logger
    response = faraday_connection.get('result/studentInfo', studentId: student_id)
    logger.info("(get_student_info:response) #{student_id} #{response.status}") if logger
    parsed_student_info = parse_student_info(response.body)
    if parsed_student_info[:student_id].nil?
      logger.info("(get_student_info:result) #{student_id} [invalid]") if logger
      return nil
    end
    logger.info("(get_student_info:result) #{student_id} [valid]") if logger
    parsed_student_info
  end

  # get semester result by the faraday connection
  # requires student_id and semester_id
  # returns semester results for the courses taken
  # returns nil if not found
  # will throw exception if problem faced during connection call
  def self.get_semester_result(student_id, semester_id, logger = nil, faraday_connection = FARADAY_CONNECTION_GEN.call())
    logger.info("(get_semester_result:request) #{student_id}:#{semester_id}") if logger
    response = faraday_connection.get('result', studentId: student_id, semesterId: semester_id)
    logger.info("(get_semester_result:response) #{student_id}:#{semester_id} #{response.status}") if logger
    parsed_semester_result = parse_semester_result(response.body)
    if parsed_semester_result.length = 0
      logger.info("(get_semester_result:result) #{student_id}:#{semester_id} [invalid]") if logger
      return nil
    end
    logger.info("(get_semester_result:result) #{student_id}:#{semester_id} [valid]") if logger
    parsed_semester_result
  end

  # updates a single student info given student_id and faraday_connection
  def self.update_student_info(student_id, logger = nil, faraday_connection = FARADAY_CONNECTION_GEN.call())
    student_info = get_student_info(student_id, logger, faraday_connection)
    unless student_info
      logger.info("(update_student_info) #{student_id} [failed to get info, aborting update]") if logger
      return nil
    end
    student = Student.find_by(student_id: student_info[:student_id])
    if student
      student.update(**student_info)
      logger.info("(update_student_info) #{student_id} [found in db and updated]") if logger
      student
    else
      begin
        student = Student.create(**student_info)
        logger.info("(update_student_info) #{student_id} [new insert in db]") if logger
        student
      rescue StandardError => e
        logger.error("(update_student_info) #{student_id} [#{e}]") if logger
        raise StudentNull.new(student_id, e)
      end
    end
  end

  # updates a single semester_result given student_id, semester_id and faraday_connection
  def self.update_semester_result(student_id, semester_id, logger = nil, faraday_connection = FARADAY_CONNECTION_GEN.call())
    student = Student.find_by(student_id: student_id)

    unless student
      logger.info("(update_semester_result) #{student_id}:#{semester_id} [not found in db]") if logger
      student = update_student_info(student_id, logger, faraday_connection)
      unless student
        if logger
          logger.warning("(update_semester_result) #{student_id}:#{semester_id} [could not find student info, aborting]")
        end
        return nil
      end
    end

    semester_result = get_semester_result(student_id, semester_id, logger, faraday_connection)

    unless semester_result
      if logger
        logger.warning("(update_semester_result) #{student_id}:#{semester_id} [no semester result found, aborting]")
      end
      return nil
    end

    updated_semester_result = []
    new_insertion = 0
    semester_result.each do |ssr|
      tssr = student.semester_results.find_by(semester_id: ssr[:semester_id], course_id: ssr[:course_id])
      if tssr
        tssr.update(**ssr)
        if logger
          logger.info("(update_semester_result) #{student_id}:#{semester_id} [#{ssr[:course_id]}:#{ssr[:course_title]} found in db, updated]")
        end
      else
        tssr = SemesterResult.create(**ssr)
        if logger
          logger.info("(update_semester_result) #{student_id}:#{semester_id} [#{ssr[:course_id]}:#{ssr[:course_title]} not found in db, created]")
        end
        new_insertion += 1
      end
      updated_semester_result << tssr
    end

    if logger
      logger.info("(update_semester_result) #{student_id}:#{semester_id} [#{new_insertion} created, #{updated_semester_result.length - new_insertion} updated]")
    end
    updated_semester_result
  end
end
