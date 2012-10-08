module Gurobi
class Constr
  # @return [Gurobi::LinExpr, Gurobi::Var]
  attr_reader :lhs

  # @return [Gurobi::LinExpr, Gurobi::Var, Float, Fixnum]
  attr_reader :rhs

  # @return [Fixnum] GRB::EQUAL, GRB::LESS_EQUAL or GRB::GREATER_EQUAL
  attr_reader :sense

  # @return [String, Symbol]
  attr_reader :name

  # @param lhs [Gurobi::LinExpr, Gurobi::Var, Float, Fixnum]
  # @param sense [Fixnum, String]
  # @param rhs [Gurobi::LinExpr, Gurobi::Var, Float, Fixnum]
  # @param (see #name=)
  def initialize(lhs, sense, rhs, name = nil)
    case lhs
    when LinExpr, Var
    when Float, Fixnum; lhs = LinExpr.new([], lhs)
    else raise Error, "invalid lhs: #{lhs.inspect}"
    end

    case rhs
    when LinExpr, Var, Float, Fixnum
    else raise Error, "invalid rhs: #{rhs.inspect}"
    end

    @lhs = lhs
    @rhs = rhs

    self.sense = sense
    self.name  = name
  end

  # Creates GRBConstr
  #
  # @param grb_model [GRBModel]
  # @return [nil]
  def gurobize(grb_model)
    raise Error, "already gurobized: #{inspect}" if @grb_constr
    @grb_constr = grb_model.add_constr(
      @lhs.send(:to_gurobi),
      @sense,
      @rhs.respond_to?(:to_gurobi, true) ? @rhs.send(:to_gurobi) : @rhs,
      @name.to_s
    )
    nil
  end

  # @param sense [Fixnum, String]
  def sense=(sense)
    @sense =
      case sense
      when '=', '==', '==='; GRB::EQUAL
      when '<', '<=';        GRB::LESS_EQUAL
      when '>', '>=';        GRB::GREATER_EQUAL
      when GRB::EQUAL, GRB::LESS_EQUAL, GRB::GREATER_EQUAL; sense
      else raise Error, "invalid sense: #{sense.inspect}"
      end
    @grb_constr.set(GRB::CharAttr::Sense, @sense) if @grb_constr
  end

  # @param name [String, Symbol]
  def name=(name)
    @name = name
    @grb_constr.set(GRB::StringAttr::ConstrName, @name.to_s) if @grb_constr
  end

  # @return [Boolean]
  def iis?
    iis_constr > 0
  end

  # @return [String]
  def inspect
    '<Gurobi::Constr%s [%s %s %s]>' % [
      @name.to_s.empty? ? '' : ":#@name",
      @lhs.inspect,
      case @sense
      when GRB::EQUAL;         '='
      when GRB::LESS_EQUAL;    '<='
      when GRB::GREATER_EQUAL; '>='
      else raise MustNotHappen, "invalid sense: #{@sense.inspect}"
      end,
      @rhs.inspect,
    ]
  end

  private

  # @return [GRBConstr]
  def grb_constr
    raise Error, "not yet gurobized: #{inspect}" unless @grb_constr
    @grb_constr
  end

  # Call by Gurobi::Model#update
  #
  # @return [void]
  def update
    sync_name
    set_attributes!
  end

  # @return [void]
  def sync_name
    @name = grb_constr.get(GRB::StringAttr::ConstrName)
  end

  # Creates attribute accessors
  extend Attribute
  attributes :@grb_constr, %w(
    Pi         pi          No
    Slack      slack       No
    CBasis     c_basis     Yes
    DStart     d_start     Yes
    IISConstr  iis_constr  No
    SARHSLow   sa_rhs_low  No
    SARHSUp    sa_rhs_up   No
    FarkasDual farkas_dual No
  )
end
end
