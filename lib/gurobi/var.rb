require 'forwardable'

module Gurobi
class Var
  extend Forwardable

  class << self
    # @return [Gurobi::Var]
    # @see Gurobi::Model#add_binary_var
    def create_binary(*args)
      keyword_args = args.last.is_a?(Hash) ? args.pop : {}
      keyword_args = { lb: 0.0, ub: 1.0 }.merge(keyword_args)
      new(*args, keyword_args.merge(vtype: GRB::BINARY))
    end

    # @return [Gurobi::Var]
    # @see Gurobi::Model#add_continuous_var
    def create_continuous(*args)
      keyword_args = args.last.is_a?(Hash) ? args.pop : {}
      new(*args, keyword_args.merge(vtype: GRB::CONTINUOUS))
    end

    # @return [Gurobi::Var]
    # @see Gurobi::Model#add_integer_var
    def create_integer(*args)
      keyword_args = args.last.is_a?(Hash) ? args.pop : {}
      new(*args, keyword_args.merge(vtype: GRB::INTEGER))
    end

    private

    # @return [Hash]
    # @see Gurobi::Model#add_var
    def parse_initialize_arguments(*args)
      original_args = args.dup
      keyword_args = args.last.is_a?(Hash) ? args.pop : {}
      range = keyword_args[:range]
      {
        lb:    range && range.begin ||
               keyword_args[:lb]    || args.shift || 0.0,
        ub:    range && range.end   ||
               keyword_args[:ub]    || args.shift || GRB::INFINITY,
        obj:   keyword_args[:obj]   || args.shift || 0.0,
        vtype: keyword_args[:vtype] || args.shift || GRB::CONTINUOUS,
        name:  keyword_args[:name]  || args.shift,
      }.tap do
        unless args.empty? &&
            (keyword_args.keys - [:lb, :ub, :range, :obj, :vtype, :name]).empty?
          raise Error, "invalid arguments: #{original_args}"
        end
      end
    end
  end

  # @return [Float, Fixnum]
  attr_reader :lb

  # @return [Float, Fixnum]
  attr_reader :ub

  # @return [Float, Fixnum]
  attr_reader :obj

  # @return [Fixnum] GRB::CONTINUOUS, GRB::BINARY, ...
  attr_reader :vtype

  # @return [String, Symbol]
  attr_reader :name

  def_delegators :to_lin_expr, :-@, :+, :-, :*, :===, :<=, :>=

  # @see Gurobi::Model#add_var
  def initialize(*args)
    keyword_args = self.class.send(:parse_initialize_arguments, *args)
    self.lb    = keyword_args[:lb]
    self.ub    = keyword_args[:ub]
    @obj       = keyword_args[:obj]
    self.vtype = keyword_args[:vtype]
    @name      = keyword_args[:name]
  end

  # @return [Gurobi::LinExpr]
  def to_lin_expr
    LinExpr.new([Term.new(1, self)])
  end

  # @param grb_model [GRBModel]
  # @return [nil]
  def gurobize(grb_model)
    raise Error, "already gurobized: #{inspect}" if @grb_var
    @grb_var = grb_model.add_var(@lb, @ub, @obj, @vtype, @name.to_s)
    nil
  end

  # @param lb [Float, Fixnum]
  def lb=(lb)
    @lb = lb
    @lb =   GRB::INFINITY if @lb ==   Float::INFINITY
    @lb = - GRB::INFINITY if @lb == - Float::INFINITY
    @grb_var.set(GRB::DoubleAttr::LB, @lb) if @grb_var
  end

  # @param ub [Float, Fixnum]
  def ub=(ub)
    @ub = ub
    @ub =   GRB::INFINITY if @ub ==   Float::INFINITY
    @ub = - GRB::INFINITY if @ub == - Float::INFINITY
    @grb_var.set(GRB::DoubleAttr::UB, @ub) if @grb_var
  end

  # @param obj [Float, Fixnum]
  def obj=(obj)
    @obj = obj
    @grb_var.set(GRB::DoubleAttr::Obj, @obj) if @grb_var
  end

  # @param vtype [Fixnum, Symbol, String]
  def vtype=(vtype)
    @vtype =
      case vtype.is_a?(String) ? vtype.upcase.to_sym : vtype
      when GRB::CONTINUOUS, :CONTINUOUS, :C; GRB::CONTINUOUS
      when GRB::BINARY,     :BINARY,     :B; GRB::BINARY
      when GRB::INTEGER,    :INTEGER,    :I; GRB::INTEGER
      when GRB::SEMICONT,   :SEMICONT,   :S; GRB::SEMICONT
      when GRB::SEMIINT,    :SEMIINT,    :N; GRB::SEMIINT
      else raise Error, "invalid vtype: #{vtype.inspect}"
      end
    @grb_var.set(GRB::CharAttr::VType, @vtype) if @grb_var
  end

  # @param name [String, Symbol]
  def name=(name)
    @name = name
    @grb_var.set(GRB::StringAttr::VarName, @name.to_s) if @grb_var
  end

  # @return [Boolean]
  def binary?
    @vtype == GRB::BINARY
  end

  # @return [Boolean]
  def continuous?
    @vtype == GRB::CONTINUOUS
  end

  # @return [Boolean]
  def integer?
    @vtype == GRB::INTEGER
  end

  # @return [self, nil]
  def to_binary!
    if binary?
      nil
    else
      self.vtype = GRB::BINARY
      self
    end
  end

  # @return [self, nil]
  def to_continuous!
    if continuous?
      nil
    else
      self.vtype = GRB::CONTINUOUS
      self
    end
  end

  # @return [self, nil]
  def to_integer!
    if integer?
      nil
    else
      self.vtype = GRB::INTEGER
      self
    end
  end

  # @return [Boolean]
  def iis?
    iis_lb? || iis_ub?
  end

  # @return [Boolean]
  def iis_lb?
    iis_lb > 0
  end

  # @return [Boolean]
  def iis_ub?
    iis_ub > 0
  end

  # @return [String]
  def inspect
    "#@name:#{@vtype.chr}"
  end

  private

  # @return [GRBVar]
  def grb_var
    raise Error, "not yet gurobized: #{inspect}" unless @grb_var
    @grb_var
  end
  alias to_gurobi grb_var

  # Call by Gurobi::Model#update
  #
  # @return [void]
  def update
    sync_name
    set_attributes!
  end

  # @return [void]
  def sync_name
    @name = grb_var.get(GRB::StringAttr::VarName)
  end

  # Creates attribute accessors
  extend Attribute
  attributes :@grb_var, %w(
    X              x               No
    Xn             xn              No
    RC             rc              No
    Start          start           Yes
    BranchPriority branch_priority Yes
    VBasis         v_basis         Yes
    PStart         p_start         Yes
    IISLB          iis_lb          No
    IISUB          iis_ub          No
    SAObjLow       sa_obj_low      No
    SAObjUp        sa_obj_up       No
    SALBLow        sa_lb_low       No
    SALBUp         sa_lb_up        No
    SAUBLow        sa_ub_low       No
    SAUBUp         sa_ub_up        No
    UnbdRay        unbd_ray        No
  )
end
end
