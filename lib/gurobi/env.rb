require 'forwardable'
require 'tempfile'

module Gurobi
class Env
  java_import 'gurobi.GRBEnv'

  extend Forwardable

  class << self
    # @param name [Symbol, String]
    # @return [DoubleParam, IntParam, StringParam]
    def param_by_name(name)
      @_param_by_name ||= Hash[
        [
          GRB::DoubleParam,
          GRB::IntParam,
          GRB::StringParam,
        ].flat_map do |mod|
          mod.constants.map do |constant_name|
            [constant_name, mod.const_get(constant_name)]
          end
        end
      ]

      name = name.to_sym if name.respond_to?(:to_sym)
      @_param_by_name[name] or
        raise Error, "invalid gurobi parameter name: #{name.inspect}"
    end

    # @param (see #get)
    # @param value [#to_f, #to_i, #to_s]
    # @return [Float, Fixnum, String]
    def cast_param_value(param, value)
      case param; when Symbol, String
        return value if private_parameter_name?(param)
        param = param_by_name(param)
      end

      case param
      when GRB::DoubleParam; value.to_f
      when GRB::IntParam;    value.to_i
      when GRB::StringParam; value.to_s
      else raise Error, "invalid gurobi parameter: #{param.inspect}"
      end
    end

    # @param param [Symbol, String]
    # @return [Boolean]
    def private_parameter_name?(param)
      param.to_s.start_with?('GURO_')
    end
  end

  # @return [GRBEnv]
  attr_reader :grb_env

  def_delegators :grb_env,
    :dispose, :error_msg, :message, :release,
    :read_params, :reset_params, :write_params

  def initialize(*args)
    @grb_env = GRBEnv.new(*args)
  end

  # @param param [DoubleParam, IntParam, StringParam, Symbol, String]
  # @return [Float, Fixnum, String]
  def get(param)
    case param; when Symbol, String
      if self.class.private_parameter_name?(param)
        return get_by_file(param)
      else
        param = self.class.param_by_name(param)
      end
    end

    @grb_env.get(param)
  end

  # @param param [DoubleParam, IntParam, StringParam, Symbol, String, Enumerable]
  # @param value [Float, Fixnum, String]
  # @return [void]
  def set(param, value = nil)
    if param.is_a?(Enumerable)
      private, public = param.partition do |_param, _value|
        self.class.private_parameter_name?(_param)
      end

      public.each do |_param, _value|
        set(_param, _value)
      end
      set_by_file(private)

      return
    end

    raise Error, "invalid param value: #{value.inspect}" unless value

    case param; when Symbol, String
      if self.class.private_parameter_name?(param)
        return set_by_file(param, value)
      else
        param = self.class.param_by_name(param)
      end
    end

    @grb_env.set(param, value)
  end

  # @param (see #get)
  # @return [Array<Float, Fixnum, String>]
  def param_info(param)
    case param; when Symbol, String
      param = self.class.param_by_name(param)
    end

    type = param.class.name[/(\w+)(?=Param$)/].downcase
    info = Java.send(type)[4].new
    @grb_env.get_param_info(param, info)
    info.to_a
  end

  private

  # @param (see #get)
  # @return [String]
  def get_by_file(param)
    prm_content = Tempfile.open(%w( gurobi-jruby .prm )) do |file|
      write_params(file.path)
      file.read
    end
    parse_prm_format(prm_content)[param.to_s]
  end

  # @param (see #set)
  # @return [void]
  def set_by_file(param, value = nil)
    param = { param => value } unless param.is_a?(Enumerable)

    Tempfile.open(%w( gurobi-jruby .prm )) do |file|
      param.each do |_param, _value|
        file.puts "#{_param} #{_value}"
      end
      file.flush

      read_params(file.path)
    end
  end

  # Parses PRM format
  #
  # @param string [String]
  # @return [Hash<String, String>]
  # @see http://www.gurobi.com/documentation/5.0/reference-manual/node753
  def parse_prm_format(string)
    Hash[
      string.each_line.map do |line|
        line.strip!
        next if line.start_with?('#')
        line.split(/\s+/, 2)
      end
    ]
  end
end
end
