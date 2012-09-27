require 'gurobi.jar'
require 'gurobi/core_ext'

module Gurobi
  autoload :Constr,  'gurobi/constr'
  autoload :Env,     'gurobi/env'
  autoload :LinExpr, 'gurobi/lin_expr'
  autoload :Model,   'gurobi/model'
  autoload :Term,    'gurobi/term'
  autoload :Var,     'gurobi/var'

  autoload :Attribute,     'gurobi/attribute'
  autoload :MustNotHappen, 'gurobi/exceptions'
  autoload :Error,         'gurobi/exceptions'
  autoload :NativeError,   'gurobi/exceptions'

  java_import 'gurobi.GRB'
end
