require 'logger'

module DRT 
    DRT_DIRPATH = ->(){
        return File.join(ENV["HOME"], ".drt")
    }
    DRT_CONFIGPATH = -> (){
        return File.join(DRT_DIRPATH, "drt.config")
    }
    class Logger
        def initialize()
            @log_path = 
            @logger = Logger.new()
    end
    class DRT 
        # get student info from result page
        def self.studentInfoFromResultPage(student_id)
        end
    end
end
