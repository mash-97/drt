# frozen_string_literal: true

require 'logger'
require 'yaml'
require 'faraday'
require 'active_record'

require_relative 'key_maps'
require_relative 'migrator'
require_relative 'models'

# DIU student Result Trends
module DRT
  # module to maintain structure
  DRT_DIRPATH = File.join(ENV['HOME'], '.drt')
  DRT_CONFIGPATH = File.join(DRT_DIRPATH, 'drt_config.yml')
  DRT_LOGPATH = File.join(DRT_DIRPATH, 'drt.log')

  DEFAULT_DB_PATH = File.join(DRT_DIRPATH, 'drt.db')
  DEFAULT_DB_LOG_PATH = File.join(DRT_DIRPATH, 'drt_db.log')

  LOGGER_GEN = lambda do |log_path = DRT_LOGPATH|
    l = Logger.new(log_path)
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
    def initialize(config, logger = LOGGER_GEN.call())
      @faraday_connection = FARADAY_CONNECTION_GEN.call
      @config = config
      @logger = logger
      @db = DB_CONNECTION_GEN.call(@config.db_path, @config.db_log_path)
      unless @db.connection.table_exists?(:students) || @db.connection.table_exists?(:semester_results)
        DRTMigrator.migrate(:up)
      end
    end

    def swing_db_for_student_info(**kwargs)
      student_ids = kwargs[:student_ids] or []
      student_ids.each do |si|
        @logger.info("Updating student info (#{si})")
        puts("\n\n==> Updating student info (#{si})")
        result = ::DRT.update_student_info(si, @faraday_connection)
        puts("==> Student ID: #{result['student_id']}, Name: #{result['student_name']}")
      end
    end

    def swing_db_for_semester_result(**kwargs)
      total_updates = 0
      total_not_found_students = 0

      semester_ids = kwargs[:semester_ids] or []
      student_ids = kwargs[:student_ids] or []
      student_ids.each do |si|
        puts("\n\n==> For Student (#{si})")
        semester_ids.each do |semsi|
          begin
            @logger.info("Updating student semester result (#{si}, #{semsi})")
            result = ::DRT.update_semester_result(si, semsi, @faraday_connection)
            puts("==> semester_id: #{semsi} total_course_taken: #{result.length}")
            total_updates += 1
          rescue StudentNull => e
            puts("##> Not Found! -- #{e}")
            total_not_found_students += 1
            break
          end
        end
        puts("\n\n\n")
      end
      [total_updates, total_not_found_students]
    end

    def detect_ranges(semester_code, dept_code, primary_id_range)
      result = ::DRT.detect_range_by_student_info_hit(semester_code, dept_code, primary_id_range, @faraday_connection)
      @logger.info("Detect Range for #{semester_code}-#{dept_code}-#{primary_id_range} -- result: #{result}")
      result
    end
  end

  def self.request_student_info(student_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result/studentInfo', studentId: student_id)
    response.body
  end

  def self.get_student_info(student_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result/studentInfo', studentId: student_id)
    parsed_student_info = parse_student_info(response.body)

    return nil if parsed_student_info[:student_id].nil?

    parsed_student_info
  end

  def self.request_semester_result(student_id, semester_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result', studentId: student_id, semesterId: semester_id)
    response.body
  end

  # updates a single student info given student_id and faraday_connection
  def self.update_student_info(student_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    latest_student_info = request_student_info(student_id, faraday_connection)
    student = Student.find_by(student_id: student_id)
    parsed_student_info = parse_student_info(latest_student_info)

    if student
      student.update(**parsed_student_info)
      student
    else
      begin
        Student.create(**parsed_student_info)
      rescue StandardError => e
        raise StudentNull.new(student_id, e)
      end
    end
  end

  def self.detect_range_by_student_info_hit(semester_code, dept_code, primary_id_range, faraday_connection = FARADAY_CONNECTION_GEN.call())
    ranges = []
    first = primary_id_range.first
    prev = nil
    primary_id_range.each do |rid|
      student_id = [semester_code.to_s, dept_code.to_s, rid.to_s].join('-')
      student_info = request_student_info(student_id, faraday_connection)
      student_info = parse_student_info(student_info)
      puts("\n\n==> student_info: #{student_info}")
      if student_info[:student_id].nil?
        ranges << (first..prev) unless prev.nil?
        first = nil
        prev = nil
      else
        first = rid if first.nil?
        prev = rid
      end
    end
    ranges << (first..prev) unless prev.nil?
    ranges
  end

  # updates a single semester_result given student_id, semester_id and faraday_connection
  def self.update_semester_result(student_id, semester_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    latest_semester_result = request_semester_result(student_id, semester_id, faraday_connection)
    student = Student.find_by(student_id: student_id)

    student ||= update_student_info(student_id)

    parsed_semester_result = parse_semester_result(latest_semester_result)

    updated_semester_result = []
    parsed_semester_result.each do |ssr|
      tssr = student.semester_results.find_by(semester_id: ssr[:semester_id], course_id: ssr[:course_id])
      if tssr
        tssr.update(**ssr)
      else
        tssr = SemesterResult.create(**ssr)
      end
      updated_semester_result << tssr
    end

    updated_semester_result
  end
end
