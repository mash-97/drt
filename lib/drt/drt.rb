require 'logger'
require 'yaml'
require 'faraday'

module DRT 

    DRT_DIRPATH = File.join(ENV["HOME"], ".drt")
    DRT_CONFIGPATH = File.join(DRT_DIRPATH, "drt_config.yml")
    DRT_LOGPATH = File.join(DRT_DIRPATH, "drt.log")
	
	LOGGER_GEN = ->(log_path=DRT_LOGPATH) do
		L = Logger.new(log_path)
		L.formatter = Proc.new{
			|severity, datetime, progname, msg|
			datetime = datetime.strftime("%d-%m-%Y %H:%M:%S")
			if progname then
				"[#{datetime}]: (#{severity}) (#{progname}) => #{msg}" 
			else
				"[#{datetime}]: (#{severity}) => #{msg}" 
			end
		}
	end
	
	SITE_URL = "http://software.diu.edu.bd:8189"
	FARADAY_CONNECTION_GEN = ->() do
		Faraday.new(
				url: DRT::SITE_URL,
				headers: {
					'Content-Type' => "application/json"
				}
			){ |faraday|
				faraday.request :json
				faraday.response :json
				
			}
	end
    class Config
		attr_accessor :db_path
		
		def initialize(config_path = DRT_CONFIGPATH)
			@config_path = config_path
			@configs = Config.loadConfigs(@config_path)
			@db_path = Config.parseConfigs(@configs)
		end
		
		def self.parseConfigs(configs_hash)
			db_path = configs_hash["db_path"]
			return [db_path]
		end
		
		def self.loadConfigs(config_path)
			return YAML.load_file(config_path)
		end
	end
	
    class DRT 
        # get student info from result page
        def initialize(config, logger = DRT::LOGGER_GEN.call())
			@faraday_connection = DRT::FARADAY_CONNECTION_GEN.call()
			@config = config
			@logger = logger
		end
		
		def requestStudentInfo(student_id)
			pusts("faraday connection: #{@faraday_connection}")
			response = @faraday_connection.get("result/studentInfo", studentId: student_id)
			return response.body
		end
    end
	def requestStudentInfo(faraday_connection=DRT::FARADAY_CONNECTION_GEN.call(), student_id)
		puts("faraday connection: #{faraday_connection}")
		response = faraday_connection.get("result/studentInfo", studentId: student_id)
		return response.body
	end
end
