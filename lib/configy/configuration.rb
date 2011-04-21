require 'erb'
require 'yaml'

module Configy
  @@load_path = nil
  @@section = nil

  def self.load_path=(val)
    @@load_path = val
  end

  def self.section=(val)
    @@section = val
  end

  def self.load_path
    if @@load_path
      return @@load_path
    elsif defined? Rails
      return Rails.root.join("config")
    elsif defined? RAILS_ROOT
      return "#{RAILS_ROOT}/config"
    elsif defined? RACK_ROOT
      return "#{RACK_ROOT}/config"
    else
      return 'config'
    end
  end

  def self.section
    if @@section
      return @@section
    elsif defined? Rails
      return Rails.env
    elsif defined? RAILS_ENV
      return RAILS_ENV
    elsif defined? RACK_ENV
      return RACK_ENV
    else
      return 'development'
    end
  end

  def self.camelize(phrase)
    camelized = phrase.gsub(/^[a-z]|\s+[a-z]|_+[a-z]|-+[a-z]/i) { |a| a.upcase }
    camelized.gsub!(/\s/, '')
    camelized.gsub!(/_/, '')
    camelized.gsub!(/-/, '')
    return camelized
  end


  def self.create(file)
    instance_eval <<-"end;", __FILE__, __LINE__ + 1
      module ::#{camelize(file.to_s)}
        class << self
          @app_config
          @file_mtime
          @local_file_mtime

          def file_path
            File.join(Configy.load_path, "#{file.to_s}.yml")
          end

          def local_file_path
            File.join(Configy.load_path, "#{file.to_s}.local.yml")
          end

          def method_missing(param)
            build_config if can_build_config?
            @app_config.send(param)
          end

          def can_build_config?
            @app_config.nil? ||
            @file_mtime && @file_mtime < File.mtime(file_path) ||
            @local_file_mtime && @local_file_mtime < File.mtime(local_file_path)
          end

          def build_config
            @app_config = Configy::Configuration.new
            @app_config.use_file!(file_path)
            @file_mtime = File.mtime(file_path)

            if File.exists?(local_file_path)
              @app_config.use_file!(local_file_path)
              @local_file_mtime = File.mtime(local_file_path)
            end

            @app_config.use_section!(Configy.section)
          end
        end
      end
    end;
  end

  class Configuration

    def initialize(file = nil)
      @sections = {}
      @params = {}
      use_file!(file) if file
    end

    def use_file!(file)
      begin
        hash = YAML::load(ERB.new(IO.read(file)).result)
        @sections.merge!(hash) {|key, old_val, new_val| (old_val || new_val).merge new_val }
        @params.merge!(@sections['common'])
      rescue; end
    end

    def use_section!(section)
      @params.merge!(@sections[section.to_s]) if @sections.key?(section.to_s)
    end

    def method_missing(param)
      param = param.to_s
      if @params.key?(param)
        @params[param]
      else
        raise "Invalid Configy::Configuration Parameter " + param
      end
    end

  end

end