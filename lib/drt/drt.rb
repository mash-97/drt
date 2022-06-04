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

  LOGGER_GEN = lambda do |log_path = DRT_LOGPATH|
    l = Logger.new(log_path)
    l.formatter = proc do |severity, datetime, progname, msg|
      datetime = datetime.strftime('%d-%m-%Y %H:%M:%S')
      if progname
        "[#{datetime}]: (#{severity}) (#{progname}) => #{msg}"
      else
        "[#{datetime}]: (#{severity}) => #{msg}"
      end
    end
  end

  SITE_URL = 'http://software.diu.edu.bd:8189'.freeze
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

  DB_CONNECTION_GEN = lambda do |db_path, log_path|
    ActiveRecord::Base.establish_connection(adapter: :sqlite3, database: db_path, logger: Logger.new(log_path))
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

    def initialize(config_path = DRT_CONFIGPATH)
      @config_path = config_path
      @configs = Config.load_configs(@config_path)
      @db_path, @db_log_path = Config.parse_configs(@configs)
    end

    def self.parse_configs(configs_hash)
      db_path = configs_hash['db_path']
      db_log_path = configs_hash['db_log_path']
      [db_path, db_log_path]
    end

    def self.load_configs(config_path)
      YAML.load_file(config_path)
    end
  end

  ##
  # DIU student Result Trends Class
  class DRT
    ##
    # This class does the heavy work
    def initialize(config, logger = DRT::LOGGER_GEN.call())
      @faraday_connection = DRT::FARADAY_CONNECTION_GEN.call
      @config = config
      @logger = logger
      @db = DRT::DB_CONNECTION_GEN.call(@config.db_path, @config.db_log_path)
    end
  end

  def self.request_student_info(student_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result/studentInfo', studentId: student_id)
    response.body
  end

  def self.request_semester_result(student_id, semester_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result', studentId: student_id, semesterId: semester_id)
    response.body
  end

  # updates a single student info given student_id and faraday_connection
  def self.update_student_info(student_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    latest_student_info = request_student_info(student_id, faraday_connection)
    puts("==> latest_student_info: #{latest_student_info.to_s}")
    student = Student.find_by(student_id: student_id)
    parsed_student_info = parse_student_info(latest_student_info)

    puts("==> parsed_student_info: #{parsed_student_info.to_s}")

    if student
      student.update(**parsed_student_info)
      student
    else
      begin
        Student.create(**parsed_student_info)
      rescue StandardError => exception
        raise StudentNull(student_id, exception)
      end
    end
  end

  # updates a single semester_result given student_id, semester_id and faraday_connection
  def self.update_semester_result(student_id, semester_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    latest_semester_result = request_semester_result(student_id, semester_id, faraday_connection)
    puts("==> latest_semester_result: #{latest_semester_result.to_s}")
    student = Student.find_by(student_id: student_id)

    student ||= update_student_info(student_id)

    parsed_semester_result = parse_semester_result(latest_semester_result)

    puts("==> parsed_semester_result: #{parsed_semester_result.to_s}")

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

    return updated_semester_result
  end
end
