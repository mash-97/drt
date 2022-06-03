require 'logger'
require 'yaml'
require 'faraday'
require 'active_record'

module DRT
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

  class Config
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

  class DRT
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

  def self.request_student_result(student_id, semester_id, faraday_connection = FARADAY_CONNECTION_GEN.call())
    response = faraday_connection.get('result', studentId: student_id, semesterId: semester_id)
    response.body
  end
end
