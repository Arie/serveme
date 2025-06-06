# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `dry-logic` gem.
# Please instead update this file by running `bin/tapioca gem dry-logic`.


# source://dry-logic//lib/dry/logic.rb#6
module Dry
  class << self
    # source://dry-configurable/1.3.0/lib/dry/configurable.rb#11
    def Configurable(**options); end

    # source://dry-core/1.1.0/lib/dry/core.rb#52
    def Equalizer(*keys, **options); end

    # source://dry-types/1.8.2/lib/dry/types.rb#253
    def Types(*namespaces, default: T.unsafe(nil), **aliases); end
  end
end

# source://dry-logic//lib/dry/logic.rb#7
module Dry::Logic
  include ::Dry::Core::Constants

  class << self
    # source://dry-logic//lib/dry/logic/rule.rb#7
    def Rule(*args, **options, &block); end

    # source://dry-logic//lib/dry/logic.rb#10
    def loader; end
  end
end

# source://dry-logic//lib/dry/logic/appliable.rb#5
module Dry::Logic::Appliable
  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/appliable.rb#14
  def applied?; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/appliable.rb#22
  def failure?; end

  # source://dry-logic//lib/dry/logic/appliable.rb#6
  def id; end

  # source://dry-logic//lib/dry/logic/appliable.rb#10
  def result; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/appliable.rb#18
  def success?; end

  # source://dry-logic//lib/dry/logic/appliable.rb#26
  def to_ast; end
end

# source://dry-logic//lib/dry/logic/builder.rb#8
module Dry::Logic::Builder
  # Predicate and operation builder
  #
  # @example Check if input is zero
  #   is_zero = Dry::Logic::Builder.call do
  #   negation { lt?(0) ^ gt?(0) }
  #   end
  #
  #   p is_zero.call(1) # => false
  #   p is_zero.call(0) # => true
  #   p is_zero.call(-1) # => false
  # @return [Builder::Result]
  #
  # source://dry-logic//lib/dry/logic/builder.rb#31
  def build(&_arg0); end

  # Predicate and operation builder
  #
  # @example Check if input is zero
  #   is_zero = Dry::Logic::Builder.call do
  #   negation { lt?(0) ^ gt?(0) }
  #   end
  #
  #   p is_zero.call(1) # => false
  #   p is_zero.call(0) # => true
  #   p is_zero.call(-1) # => false
  # @return [Builder::Result]
  #
  # source://dry-logic//lib/dry/logic/builder.rb#31
  def call(&_arg0); end

  class << self
    # Predicate and operation builder
    #
    # @example Check if input is zero
    #   is_zero = Dry::Logic::Builder.call do
    #   negation { lt?(0) ^ gt?(0) }
    #   end
    #
    #   p is_zero.call(1) # => false
    #   p is_zero.call(0) # => true
    #   p is_zero.call(-1) # => false
    # @return [Builder::Result]
    #
    # source://dry-logic//lib/dry/logic/builder.rb#31
    def call(&_arg0); end
  end
end

# source://dry-logic//lib/dry/logic/builder.rb#38
class Dry::Logic::Builder::Context
  include ::Dry::Core::Constants
  include ::Dry::Logic
  include ::Singleton::SingletonInstanceMethods
  include ::Singleton
  extend ::Singleton::SingletonClassMethods

  # Defines methods for operations and predicates
  #
  # @return [Context] a new instance of Context
  #
  # source://dry-logic//lib/dry/logic/builder.rb#68
  def initialize; end

  # @see Builder#call
  #
  # source://dry-logic//lib/dry/logic/builder.rb#47
  def call(&_arg0); end

  # Defines custom predicate
  #
  # source://dry-logic//lib/dry/logic/builder.rb#55
  def predicate(name, context = T.unsafe(nil), &block); end

  class << self
    private

    def allocate; end
    def new(*_arg0); end
  end
end

# source://dry-logic//lib/dry/logic/builder.rb#42
module Dry::Logic::Builder::Context::Predicates
  include ::Dry::Core::Constants
  include ::Dry::Logic::Predicates
  extend ::Dry::Logic::Predicates::Methods
end

# source://dry-logic//lib/dry/logic/builder.rb#9
Dry::Logic::Builder::IGNORED_OPERATIONS = T.let(T.unsafe(nil), Array)

# source://dry-logic//lib/dry/logic/builder.rb#15
Dry::Logic::Builder::IGNORED_PREDICATES = T.let(T.unsafe(nil), Array)

# source://dry-logic//lib/dry/logic/evaluator.rb#5
class Dry::Logic::Evaluator
  include ::Dry::Core::Equalizer::Methods

  # @return [Evaluator] a new instance of Evaluator
  #
  # source://dry-logic//lib/dry/logic/evaluator.rb#43
  def initialize(path); end

  # Returns the value of attribute path.
  #
  # source://dry-logic//lib/dry/logic/evaluator.rb#8
  def path; end
end

# source://dry-logic//lib/dry/logic/evaluator.rb#36
class Dry::Logic::Evaluator::Attr < ::Dry::Logic::Evaluator
  # source://dry-logic//lib/dry/logic/evaluator.rb#37
  def [](input); end

  # source://dry-logic//lib/dry/logic/evaluator.rb#37
  def call(input); end
end

# source://dry-logic//lib/dry/logic/evaluator.rb#29
class Dry::Logic::Evaluator::Key < ::Dry::Logic::Evaluator
  # source://dry-logic//lib/dry/logic/evaluator.rb#30
  def [](input); end

  # source://dry-logic//lib/dry/logic/evaluator.rb#30
  def call(input); end
end

# source://dry-logic//lib/dry/logic/evaluator.rb#10
class Dry::Logic::Evaluator::Set
  include ::Dry::Core::Equalizer::Methods

  # @return [Set] a new instance of Set
  #
  # source://dry-logic//lib/dry/logic/evaluator.rb#19
  def initialize(evaluators); end

  # source://dry-logic//lib/dry/logic/evaluator.rb#23
  def [](input); end

  # source://dry-logic//lib/dry/logic/evaluator.rb#23
  def call(input); end

  # Returns the value of attribute evaluators.
  #
  # source://dry-logic//lib/dry/logic/evaluator.rb#13
  def evaluators; end

  class << self
    # source://dry-logic//lib/dry/logic/evaluator.rb#15
    def new(paths); end
  end
end

# source://dry-logic//lib/dry/logic/operations/and.rb#5
module Dry::Logic::Operations; end

# source://dry-logic//lib/dry/logic/operations/abstract.rb#6
class Dry::Logic::Operations::Abstract
  include ::Dry::Core::Constants
  include ::Dry::Core::Equalizer::Methods
  include ::Dry::Logic::Operators

  # @return [Abstract] a new instance of Abstract
  #
  # source://dry-logic//lib/dry/logic/operations/abstract.rb#15
  def initialize(*rules, **options); end

  # source://dry-logic//lib/dry/logic/operations/abstract.rb#24
  def curry(*args); end

  # source://dry-logic//lib/dry/logic/operations/abstract.rb#20
  def id; end

  # source://dry-logic//lib/dry/logic/operations/abstract.rb#28
  def new(rules, **new_options); end

  # Returns the value of attribute options.
  #
  # source://dry-logic//lib/dry/logic/operations/abstract.rb#13
  def options; end

  # Returns the value of attribute rules.
  #
  # source://dry-logic//lib/dry/logic/operations/abstract.rb#11
  def rules; end

  # source://dry-logic//lib/dry/logic/operations/abstract.rb#36
  def to_ast; end

  # source://dry-logic//lib/dry/logic/operations/abstract.rb#32
  def with(new_options); end
end

# source://dry-logic//lib/dry/logic/operations/and.rb#6
class Dry::Logic::Operations::And < ::Dry::Logic::Operations::Binary
  # @return [And] a new instance of And
  #
  # source://dry-logic//lib/dry/logic/operations/and.rb#9
  def initialize(*_arg0, **_arg1); end

  # source://dry-logic//lib/dry/logic/operations/and.rb#38
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/and.rb#19
  def call(input); end

  # Returns the value of attribute hints.
  #
  # source://dry-logic//lib/dry/logic/operations/and.rb#7
  def hints; end

  # source://dry-logic//lib/dry/logic/operations/and.rb#14
  def operator; end

  # source://dry-logic//lib/dry/logic/operations/and.rb#14
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/attr.rb#6
class Dry::Logic::Operations::Attr < ::Dry::Logic::Operations::Key
  # source://dry-logic//lib/dry/logic/operations/attr.rb#11
  def type; end

  class << self
    # source://dry-logic//lib/dry/logic/operations/attr.rb#7
    def evaluator(name); end
  end
end

# source://dry-logic//lib/dry/logic/operations/binary.rb#6
class Dry::Logic::Operations::Binary < ::Dry::Logic::Operations::Abstract
  # @return [Binary] a new instance of Binary
  #
  # source://dry-logic//lib/dry/logic/operations/binary.rb#11
  def initialize(left, right, **options); end

  # source://dry-logic//lib/dry/logic/operations/binary.rb#17
  def ast(input = T.unsafe(nil)); end

  # Returns the value of attribute left.
  #
  # source://dry-logic//lib/dry/logic/operations/binary.rb#7
  def left; end

  # Returns the value of attribute right.
  #
  # source://dry-logic//lib/dry/logic/operations/binary.rb#9
  def right; end

  # source://dry-logic//lib/dry/logic/operations/binary.rb#21
  def to_s; end
end

# source://dry-logic//lib/dry/logic/operations/check.rb#6
class Dry::Logic::Operations::Check < ::Dry::Logic::Operations::Unary
  # @return [Check] a new instance of Check
  #
  # source://dry-logic//lib/dry/logic/operations/check.rb#20
  def initialize(*rules, **options); end

  # source://dry-logic//lib/dry/logic/operations/check.rb#40
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/check.rb#44
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/operations/check.rb#29
  def call(input); end

  # Returns the value of attribute evaluator.
  #
  # source://dry-logic//lib/dry/logic/operations/check.rb#7
  def evaluator; end

  # source://dry-logic//lib/dry/logic/operations/check.rb#25
  def type; end

  class << self
    # source://dry-logic//lib/dry/logic/operations/check.rb#9
    def new(rule, **options); end
  end
end

# source://dry-logic//lib/dry/logic/operations/each.rb#6
class Dry::Logic::Operations::Each < ::Dry::Logic::Operations::Unary
  # source://dry-logic//lib/dry/logic/operations/each.rb#25
  def [](arr); end

  # source://dry-logic//lib/dry/logic/operations/each.rb#11
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/each.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/implication.rb#6
class Dry::Logic::Operations::Implication < ::Dry::Logic::Operations::Binary
  # source://dry-logic//lib/dry/logic/operations/implication.rb#26
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/implication.rb#15
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/implication.rb#11
  def operator; end

  # source://dry-logic//lib/dry/logic/operations/implication.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/key.rb#6
class Dry::Logic::Operations::Key < ::Dry::Logic::Operations::Unary
  # @return [Key] a new instance of Key
  #
  # source://dry-logic//lib/dry/logic/operations/key.rb#25
  def initialize(*rules, **options); end

  # source://dry-logic//lib/dry/logic/operations/key.rb#46
  def [](hash); end

  # source://dry-logic//lib/dry/logic/operations/key.rb#50
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/operations/key.rb#35
  def call(hash); end

  # Returns the value of attribute evaluator.
  #
  # source://dry-logic//lib/dry/logic/operations/key.rb#7
  def evaluator; end

  # Returns the value of attribute path.
  #
  # source://dry-logic//lib/dry/logic/operations/key.rb#9
  def path; end

  # source://dry-logic//lib/dry/logic/operations/key.rb#58
  def to_s; end

  # source://dry-logic//lib/dry/logic/operations/key.rb#31
  def type; end

  class << self
    # source://dry-logic//lib/dry/logic/operations/key.rb#21
    def evaluator(name); end

    # source://dry-logic//lib/dry/logic/operations/key.rb#11
    def new(rules, **options); end
  end
end

# source://dry-logic//lib/dry/logic/operations/negation.rb#6
class Dry::Logic::Operations::Negation < ::Dry::Logic::Operations::Unary
  # source://dry-logic//lib/dry/logic/operations/negation.rb#15
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/negation.rb#11
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/negation.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/or.rb#6
class Dry::Logic::Operations::Or < ::Dry::Logic::Operations::Binary
  # source://dry-logic//lib/dry/logic/operations/or.rb#28
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/or.rb#12
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/or.rb#7
  def operator; end

  # source://dry-logic//lib/dry/logic/operations/or.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/set.rb#6
class Dry::Logic::Operations::Set < ::Dry::Logic::Operations::Abstract
  # source://dry-logic//lib/dry/logic/operations/set.rb#20
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/set.rb#24
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/operations/set.rb#11
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/set.rb#28
  def to_s; end

  # source://dry-logic//lib/dry/logic/operations/set.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operations/unary.rb#6
class Dry::Logic::Operations::Unary < ::Dry::Logic::Operations::Abstract
  # @return [Unary] a new instance of Unary
  #
  # source://dry-logic//lib/dry/logic/operations/unary.rb#9
  def initialize(*rules, **options); end

  # source://dry-logic//lib/dry/logic/operations/unary.rb#14
  def ast(input = T.unsafe(nil)); end

  # Returns the value of attribute rule.
  #
  # source://dry-logic//lib/dry/logic/operations/unary.rb#7
  def rule; end

  # source://dry-logic//lib/dry/logic/operations/unary.rb#18
  def to_s; end
end

# source://dry-logic//lib/dry/logic/operations/xor.rb#6
class Dry::Logic::Operations::Xor < ::Dry::Logic::Operations::Binary
  # source://dry-logic//lib/dry/logic/operations/xor.rb#16
  def [](input); end

  # source://dry-logic//lib/dry/logic/operations/xor.rb#20
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/operations/xor.rb#12
  def call(input); end

  # source://dry-logic//lib/dry/logic/operations/xor.rb#7
  def operator; end

  # source://dry-logic//lib/dry/logic/operations/xor.rb#7
  def type; end
end

# source://dry-logic//lib/dry/logic/operators.rb#5
module Dry::Logic::Operators
  # source://dry-logic//lib/dry/logic/operators.rb#6
  def &(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#21
  def >(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#16
  def ^(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#6
  def and(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#11
  def or(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#21
  def then(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#16
  def xor(other); end

  # source://dry-logic//lib/dry/logic/operators.rb#11
  def |(other); end
end

# source://dry-logic//lib/dry/logic/predicates.rb#12
module Dry::Logic::Predicates
  include ::Dry::Core::Constants
  extend ::Dry::Logic::Predicates::Methods

  mixes_in_class_methods ::Dry::Logic::Predicates::Methods

  class << self
    # @private
    #
    # source://dry-logic//lib/dry/logic/predicates.rb#226
    def included(other); end
  end
end

# source://dry-logic//lib/dry/logic/predicates.rb#16
module Dry::Logic::Predicates::Methods
  # source://dry-logic//lib/dry/logic/predicates.rb#39
  def [](name); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#87
  def array?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#50
  def attr?(name, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#63
  def bool?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#114
  def bytesize?(size, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#170
  def case?(pattern, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#65
  def date?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#67
  def date_time?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#81
  def decimal?(input); end

  # source://dry-logic//lib/dry/logic/predicates.rb#213
  def deprecated(name, in_favor_of); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#52
  def empty?(input); end

  # This overrides Object#eql? so we need to make it compatible
  #
  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#154
  def eql?(left, right = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#91
  def even?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#139
  def excluded_from?(list, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#151
  def excludes?(value, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#132
  def exclusion?(list, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#166
  def false?(value); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#61
  def filled?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#79
  def float?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#168
  def format?(regex, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#95
  def gt?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#99
  def gteq?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#85
  def hash?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#137
  def included_in?(list, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#141
  def includes?(value, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#127
  def inclusion?(list, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#77
  def int?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#160
  def is?(left, right); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#48
  def key?(name, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#93
  def lt?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#97
  def lteq?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#125
  def max_bytesize?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#112
  def max_size?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#123
  def min_bytesize?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#110
  def min_size?(num, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#45
  def nil?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#45
  def none?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#162
  def not_eql?(left, right); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#71
  def number?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#89
  def odd?(input); end

  # source://dry-logic//lib/dry/logic/predicates.rb#209
  def predicate(name, &_arg1); end

  # This overrides Object#respond_to? so we need to make it compatible
  #
  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#203
  def respond_to?(method, input = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#101
  def size?(size, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#83
  def str?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#69
  def time?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#164
  def true?(value); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#43
  def type?(type, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#189
  def uri?(schemes, input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#200
  def uri_rfc3986?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#172
  def uuid_v1?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#174
  def uuid_v2?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#176
  def uuid_v3?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#178
  def uuid_v4?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#180
  def uuid_v5?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#182
  def uuid_v6?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#184
  def uuid_v7?(input); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/predicates.rb#186
  def uuid_v8?(input); end

  class << self
    # source://dry-logic//lib/dry/logic/predicates.rb#17
    def uuid_format(version); end
  end
end

# source://dry-logic//lib/dry/logic/predicates.rb#23
Dry::Logic::Predicates::Methods::UUIDv1 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#25
Dry::Logic::Predicates::Methods::UUIDv2 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#27
Dry::Logic::Predicates::Methods::UUIDv3 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#29
Dry::Logic::Predicates::Methods::UUIDv4 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#31
Dry::Logic::Predicates::Methods::UUIDv5 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#33
Dry::Logic::Predicates::Methods::UUIDv6 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#35
Dry::Logic::Predicates::Methods::UUIDv7 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/predicates.rb#37
Dry::Logic::Predicates::Methods::UUIDv8 = T.let(T.unsafe(nil), Regexp)

# source://dry-logic//lib/dry/logic/result.rb#5
class Dry::Logic::Result
  # @return [Result] a new instance of Result
  #
  # source://dry-logic//lib/dry/logic/result.rb#22
  def initialize(success, id = T.unsafe(nil), &block); end

  # source://dry-logic//lib/dry/logic/result.rb#40
  def ast(input = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/result.rb#32
  def failure?; end

  # Returns the value of attribute id.
  #
  # source://dry-logic//lib/dry/logic/result.rb#18
  def id; end

  # Returns the value of attribute serializer.
  #
  # source://dry-logic//lib/dry/logic/result.rb#20
  def serializer; end

  # Returns the value of attribute success.
  #
  # source://dry-logic//lib/dry/logic/result.rb#16
  def success; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/result.rb#28
  def success?; end

  # source://dry-logic//lib/dry/logic/result.rb#44
  def to_ast; end

  # source://dry-logic//lib/dry/logic/result.rb#52
  def to_s; end

  # source://dry-logic//lib/dry/logic/result.rb#36
  def type; end

  private

  # source://dry-logic//lib/dry/logic/result.rb#58
  def visit(ast); end

  # source://dry-logic//lib/dry/logic/result.rb#72
  def visit_and(node); end

  # source://dry-logic//lib/dry/logic/result.rb#91
  def visit_hint(node); end

  # source://dry-logic//lib/dry/logic/result.rb#87
  def visit_not(node); end

  # source://dry-logic//lib/dry/logic/result.rb#77
  def visit_or(node); end

  # source://dry-logic//lib/dry/logic/result.rb#62
  def visit_predicate(node); end

  # source://dry-logic//lib/dry/logic/result.rb#82
  def visit_xor(node); end
end

# source://dry-logic//lib/dry/logic/result.rb#6
Dry::Logic::Result::SUCCESS = T.let(T.unsafe(nil), T.untyped)

# source://dry-logic//lib/dry/logic/rule.rb#15
class Dry::Logic::Rule
  include ::Dry::Core::Constants
  include ::Dry::Core::Equalizer::Methods
  include ::Dry::Logic::Operators

  # @return [Rule] a new instance of Rule
  #
  # source://dry-logic//lib/dry/logic/rule.rb#45
  def initialize(predicate, options = T.unsafe(nil)); end

  # Returns the value of attribute args.
  #
  # source://dry-logic//lib/dry/logic/rule.rb#24
  def args; end

  # Returns the value of attribute arity.
  #
  # source://dry-logic//lib/dry/logic/rule.rb#26
  def arity; end

  # source://dry-logic//lib/dry/logic/rule.rb#87
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/rule.rb#64
  def bind(object); end

  # source://dry-logic//lib/dry/logic/rule.rb#60
  def curry(*new_args); end

  # source://dry-logic//lib/dry/logic/rule.rb#75
  def eval_args(object); end

  # source://dry-logic//lib/dry/logic/rule.rb#56
  def id; end

  # Returns the value of attribute options.
  #
  # source://dry-logic//lib/dry/logic/rule.rb#22
  def options; end

  # source://dry-logic//lib/dry/logic/rule.rb#83
  def parameters; end

  # Returns the value of attribute predicate.
  #
  # source://dry-logic//lib/dry/logic/rule.rb#20
  def predicate; end

  # source://dry-logic//lib/dry/logic/rule.rb#52
  def type; end

  # source://dry-logic//lib/dry/logic/rule.rb#79
  def with(new_opts); end

  private

  # source://dry-logic//lib/dry/logic/rule.rb#93
  def args_with_names(*input); end

  class << self
    # source://dry-logic//lib/dry/logic/rule.rb#41
    def build(predicate, args: T.unsafe(nil), arity: T.unsafe(nil), **options); end

    # source://dry-logic//lib/dry/logic/rule.rb#28
    def interfaces; end

    # source://dry-logic//lib/dry/logic/rule.rb#32
    def specialize(arity, curried, base = T.unsafe(nil)); end
  end
end

# source://dry-logic//lib/dry/logic/rule/interface.rb#6
class Dry::Logic::Rule::Interface < ::Module
  # @return [Interface] a new instance of Interface
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#13
  def initialize(arity, curried); end

  # Returns the value of attribute arity.
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#9
  def arity; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#32
  def constant?; end

  # Returns the value of attribute curried.
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#11
  def curried; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#36
  def curried?; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#127
  def curried_args; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#107
  def define_application; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#91
  def define_constant_application; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#74
  def define_constructor; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#52
  def name; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#38
  def unapplied; end

  # source://dry-logic//lib/dry/logic/rule/interface.rb#131
  def unapplied_args; end

  # @return [Boolean]
  #
  # source://dry-logic//lib/dry/logic/rule/interface.rb#34
  def variable_arity?; end
end

# source://dry-logic//lib/dry/logic/rule/interface.rb#7
Dry::Logic::Rule::Interface::SPLAT = T.let(T.unsafe(nil), Array)

# source://dry-logic//lib/dry/logic/rule/predicate.rb#6
class Dry::Logic::Rule::Predicate < ::Dry::Logic::Rule
  # source://dry-logic//lib/dry/logic/rule/predicate.rb#27
  def ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/rule/predicate.rb#15
  def name; end

  # source://dry-logic//lib/dry/logic/rule/predicate.rb#27
  def to_ast(input = T.unsafe(nil)); end

  # source://dry-logic//lib/dry/logic/rule/predicate.rb#19
  def to_s; end

  # source://dry-logic//lib/dry/logic/rule/predicate.rb#11
  def type; end

  class << self
    # source://dry-logic//lib/dry/logic/rule/predicate.rb#7
    def specialize(arity, curried, base = T.unsafe(nil)); end
  end
end

# source://dry-logic//lib/dry/logic/rule_compiler.rb#5
class Dry::Logic::RuleCompiler
  # @return [RuleCompiler] a new instance of RuleCompiler
  #
  # source://dry-logic//lib/dry/logic/rule_compiler.rb#8
  def initialize(predicates); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#12
  def call(ast); end

  # Returns the value of attribute predicates.
  #
  # source://dry-logic//lib/dry/logic/rule_compiler.rb#6
  def predicates; end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#16
  def visit(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#60
  def visit_and(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#35
  def visit_attr(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#21
  def visit_check(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#44
  def visit_each(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#75
  def visit_implication(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#30
  def visit_key(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#26
  def visit_not(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#65
  def visit_or(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#48
  def visit_predicate(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#40
  def visit_set(node); end

  # source://dry-logic//lib/dry/logic/rule_compiler.rb#70
  def visit_xor(node); end
end
