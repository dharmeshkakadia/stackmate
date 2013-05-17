require 'logger'

module StackMate
module Logging
  def logger
    @logger ||= Logging.logger_for(self.class.name)
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def configure_logger_for(classname)
      logger = Logger.new(STDOUT)
      logger.progname = classname
      logger.datetime_format= '%F %T'
      logger.formatter = proc do |severity, datetime, progname, msg|
            "[#{datetime}] #{severity} #{progname} #{msg}\n"
      end
      logger
    end
  end
end
end
