module TweakDock
  module Naming
    SWIFT_KEYWORDS = %w[
      Any Protocol Self Type actor as associatedtype async await break case catch class continue default defer
      deinit do else enum extension fallthrough false fileprivate for func guard if import in init inout internal
      is let nil open operator precedencegroup private protocol public repeat rethrows return self some static
      struct subscript super switch throw throws true try typealias var where while
    ].freeze

    IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    module_function

    # "exp_ipad_sidebar" gives "ExpIpadSidebar".
    def pascal_case(key)
      key.split("_").reject(&:empty?).map { |word| word[0].upcase + word[1..] }.join
    end

    # "exp_ipad_sidebar" gives "expIpadSidebar".
    def camel_case(key)
      pascal = pascal_case(key)
      pascal[0].downcase + pascal[1..]
    end

    def identifier?(text)
      IDENTIFIER.match?(text)
    end

    def escaped(identifier)
      SWIFT_KEYWORDS.include?(identifier) || identifier == "_" ? "`#{identifier}`" : identifier
    end
  end
end
