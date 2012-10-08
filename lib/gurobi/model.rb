module Gurobi
class Model
  java_import 'gurobi.GRBModel'

  class << self
    attr_writer :var_name_prefix

    # @return [String]
    def var_name_prefix
      @var_name_prefix.to_s
    end
  end

  # @return [Fixnum] GRB::MINIMIZE or GRB::MAXIMIZE
  attr_reader :sense

  # @return [Array<Gurobi::Var>]
  attr_reader :vars

  # @return [Array<Gurobi::Constr>]
  attr_reader :constrs

  # @return [Gurobi::Env, nil]
  attr_reader :env

  # @return [Gurobi::LinExpr, nil]
  attr_accessor :objective

  def initialize
    @vars                   = []
    @constrs                = []
    @pending_vars           = []
    @pending_constrs        = []
    @sense                  = GRB::MINIMIZE
    @objective              = nil
    @duplicate_name_indexes = {}
  end

  # @overload add_var(lb = 0.0, ub = GRB::INFINITY, obj = 0.0, vtype = GRB::CONTINUOUS, name = nil)
  #   @param lb [Float, Fixnum]
  #   @param ub [Float, Fixnum]
  #   @param obj [Float, Fixnum]
  #   @param vtype [Fixnum, String, Symbol]
  #   @param name [String]
  #
  # @overload add_var(keyword_arguments = {})
  #   @param keyword_arguments [Hash]
  #   @option keyword_arguments [Float, Fixnum] :lb (0.0)
  #   @option keyword_arguments [Float, Fixnum] :ub (GRB::INFINITY)
  #   @option keyword_arguments [Float, Fixnum] :obj (0.0)
  #   @option keyword_arguments [Fixnum, String, Symbol] :vtype (GRB::CONTINUOUS)
  #   @option keyword_arguments [String] :name (nil)
  #
  # @return [Gurobi::Var]
  def add_var(*args)
    Var.new(*args).tap do |var|
      if var.name
        var.name = add_suffix_for_duplication(add_var_name_prefix(var.name))
      end
      @vars         << var
      @pending_vars << var
    end
  end

  # @method add_binary_var
  #
  # @overload add_binary_var(obj = 0.0, name = nil)
  #   @param obj [Float, Fixnum]
  #   @param name [String]
  #
  # @overload add_binary_var(keyword_arguments = {})
  #   @param keyword_arguments [Hash]
  #   @option keyword_arguments [Float, Fixnum] :obj (0.0)
  #   @option keyword_arguments [String] :name (nil)
  #
  # @return [Gurobi::Var]

  # @method add_continuous_var
  #
  # @overload add_continuous_var(lb = 0.0, ub = GRB::INFINITY, obj = 0.0, name = nil)
  #   @param lb [Float, Fixnum]
  #   @param ub [Float, Fixnum]
  #   @param obj [Float, Fixnum]
  #   @param name [String]
  #
  # @overload add_continuous_var(keyword_arguments = {})
  #   @param keyword_arguments [Hash]
  #   @option keyword_arguments [Float, Fixnum] :lb (0.0)
  #   @option keyword_arguments [Float, Fixnum] :ub (GRB::INFINITY)
  #   @option keyword_arguments [Float, Fixnum] :obj (0.0)
  #   @option keyword_arguments [String] :name (nil)
  #
  # @return [Gurobi::Var]

  # @method add_integer_var
  #
  # @overload add_integer_var(lb = 0.0, ub = GRB::INFINITY, obj = 0.0, name = nil)
  #   @param lb [Float, Fixnum]
  #   @param ub [Float, Fixnum]
  #   @param obj [Float, Fixnum]
  #   @param name [String]
  #
  # @overload add_integer_var(keyword_arguments = {})
  #   @param keyword_arguments [Hash]
  #   @option keyword_arguments [Float, Fixnum] :lb (0.0)
  #   @option keyword_arguments [Float, Fixnum] :ub (GRB::INFINITY)
  #   @option keyword_arguments [Float, Fixnum] :obj (0.0)
  #   @option keyword_arguments [String] :name (nil)
  #
  # @return [Gurobi::Var]

  # Creates add_*_var methods
  %w( binary continuous integer ).each do |type|
    class_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def add_#{type}_var(*args)
        Var.create_#{type}(*args).tap do |var|
          if var.name
            var.name = add_suffix_for_duplication(add_var_name_prefix(var.name))
          end
          @vars         << var
          @pending_vars << var
        end
      end
    EOS
  end

  # @overload add_constr(constr, name = nil)
  #   @param constr [Gurobi::Constr]
  #   @param name [String]
  # @overload add_constr(lhs, sense, rhs, name = nil)
  #   @param (see Gurobi::Constr#initialize)
  # @return [Gurobi::Constr]
  def add_constr(*args)
    case args.length
    when 1, 2
      constr, name = args
      unless constr.is_a?(Constr)
        raise Error, "invalid constr: #{constr.inspect}"
      end
    when 3, 4
      constr = Constr.new(*args.take(3))
      name   = args[3]
    else
      raise Error, "invalid args: #{args.inspect}"
    end

    constr.name = add_suffix_for_duplication(name) unless name.to_s.empty?
    @constrs         << constr
    @pending_constrs << constr
    constr
  end

  # @param sense [Fixnum, Symbol]
  def sense=(sense)
    @sense =
      case sense
      when :maximize; GRB::MAXIMIZE
      when :minimize; GRB::MINIMIZE
      when GRB::MAXIMIZE, GRB::MINIMIZE; sense
      else raise Error, "invalid sense: #{sense.inspect}"
      end
    @grb_model.set(GRB::IntAttr::ModelSense, @sense) if @grb_model
  end

  # @param expr [Gurobi::LinExpr]
  # @param (see #sense=)
  # @return [void]
  def set_objective(expr, sense = nil)
    self.objective = expr
    self.sense     = sense if sense
  end

  # @param env [Gurobi::Env]
  def env=(env)
    raise Error, 'already set env' if @env
    @env = env
  end

  # Delegates to GRBModel.update()
  #
  # @return [void]
  def update
    @pending_vars.each do |var|
      var.gurobize(grb_model)
    end
    grb_model.update
    @pending_vars.each(&:update)
    @pending_vars.clear

    @pending_constrs.each do |constr|
      constr.gurobize(grb_model)
    end
    grb_model.update
    @pending_constrs.each(&:update)
    @pending_constrs.clear

    grb_model.objective = @objective.send(:to_gurobi) if @objective
  end

  # Delegates to GRBModel.write()
  #
  # @param path [String, Pathname]
  # @return [void]
  def write(path)
    path = path.to_s if path.class.name == 'Pathname'
    update
    grb_model.write(path)
  end

  # Delegates to GRBModel.optimize()
  #
  # @return [void]
  def optimize
    update
    terminatable_block do
      grb_model.optimize
    end
  end

  # Returns GRBModel.get(GRB::IntAttr::Status) as Symbol
  #
  # @return [Symbol]
  # @see http://www.gurobi.com/documentation/5.0/reference-manual/node372
  def status
    @_statuses ||= Hash[
      GRB::Status.constants.map do |name|
        [GRB::Status.const_get(name), name.downcase]
      end
    ]
    @_statuses[grb_model.get(GRB::IntAttr::Status)]
  end

  # Defines the following methods
  #
  #   status_loaded?
  #   status_optimal?
  #   status_infeasible?
  #   ...
  #
  # @see http://www.gurobi.com/documentation/5.0/reference-manual/node372
  GRB::Status.constants.each do |name|
    class_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def status_#{name.downcase}?
        grb_model.get(GRB::IntAttr::Status) == GRB::Status::#{name}
      end
    EOS
  end

  # terminatable compute_iis
  #
  # @return [void]
  def compute_iis
    terminatable_block do
      grb_model.compute_iis
    end
  end

  private

  # @return [GRBModel]
  def grb_model
    unless @grb_model
      raise Error, 'not yet set env' unless @env
      @grb_model = GRBModel.new(@env.grb_env)
      @grb_model.set(GRB::IntAttr::ModelSense, @sense)
      set_attributes!
    end
    @grb_model
  end

  # @param name [String, Symbol]
  # @return [String]
  def add_var_name_prefix(name)
    name = name.to_s if name.is_a?(Symbol)
    self.class.var_name_prefix + name
  end

  # Adds a serial number suffix if the name is duplicate
  #
  # @param name [String, Symbol]
  # @return [String]
  def add_suffix_for_duplication(name)
    name = name.to_s if name.is_a?(Symbol)

    unless name =~ /\A#{Regexp.escape(self.class.var_name_prefix)}?\w+\z/
      raise Error, "invalid name: #{name.inspect}"
    end

    if @duplicate_name_indexes[name]
      name = "#{name}_s#{@duplicate_name_indexes[name] += 1}"
    else
      @duplicate_name_indexes[name] = 0
    end

    name
  end

  # @return the value of the block
  def terminatable_block(&block)
    signal      = :USR2
    old_command = :nil

    begin
      old_command = Signal.trap(signal) { grb_model.terminate }
      yield

    ensure
      Signal.trap(signal, old_command) unless old_command == :nil
    end
  end

  # Creates attribute accessors
  extend Attribute
  attributes :@grb_model, %w(
    NumConstrs   num_constrs    No
    NumVars      num_vars       No
    NumSOS       num_sos        No
    NumQConstrs  num_q_constrs  No
    NumNZs       num_nzs        No
    NumQNZs      num_q_nzs      No
    NumQCNZs     num_qc_nzs     No
    NumIntVars   num_int_vars   No
    NumBinVars   num_bin_vars   No
    ModelName    model_name     Yes
    ObjCon       obj_con        Yes
    ObjVal       obj_val        No
    ObjBound     obj_bound      No
    Runtime      runtime        No
    SolCount     sol_count      No
    IterCount    iter_count     No
    BarIterCount bar_iter_count No
    NodeCount    node_count     No
    IsMIP        mip?           No
    IsQP         qp?            No
    IsQCP        qcp?           No
    IISMinimal   iis_minimal    No
    MaxCoeff     max_coeff      No
    MinCoeff     min_coeff      No
    MaxBound     max_bound      No
    MinBound     min_bound      No
    MaxObjCoeff  max_obj_coeff  No
    MinObjCoeff  min_obj_coeff  No
    MaxRHS       max_rhs        No
    MinRHS       min_rhs        No
    Kappa        kappa          No
    KappaExact   kappa_exact    No
    FarkasProof  farkas_proof   No
  )
end
end
