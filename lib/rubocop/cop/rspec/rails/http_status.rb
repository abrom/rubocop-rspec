# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      module Rails
        # Enforces use of symbolic or numeric value to describe HTTP status.
        #
        # @example `EnforcedStyle: symbolic` (default)
        #   # bad
        #   it { is_expected.to have_http_status 200 }
        #   it { is_expected.to have_http_status 404 }
        #
        #   # good
        #   it { is_expected.to have_http_status :ok }
        #   it { is_expected.to have_http_status :not_found }
        #   it { is_expected.to have_http_status :success }
        #   it { is_expected.to have_http_status :error }
        #
        # @example `EnforcedStyle: numeric`
        #   # bad
        #   it { is_expected.to have_http_status :ok }
        #   it { is_expected.to have_http_status :not_found }
        #
        #   # good
        #   it { is_expected.to have_http_status 200 }
        #   it { is_expected.to have_http_status 404 }
        #   it { is_expected.to have_http_status :success }
        #   it { is_expected.to have_http_status :error }
        #
        class HttpStatus < Cop
          begin
            require 'rack/utils'
            RACK_LOADED = true
          rescue LoadError
            RACK_LOADED = false
          end

          include ConfigurableEnforcedStyle

          MSG = 'Prefer `%<prefer>s` over `%<current>s` '\
                'to describe HTTP status code.'.freeze

          def on_send(node)
            checker = checker_class.new_from_send_node(node)
            return unless checker.offensive?
            add_offense(checker.node, message: checker.message)
          end

          def support_autocorrect?
            RACK_LOADED
          end

          def autocorrect(node)
            checker = checker_class.new(node)
            replacement = checker.preferred_style
            return if replacement.nil?

            lambda do |corrector|
              corrector.replace(node.loc.expression, replacement)
            end
          end

          private

          def checker_class
            case style
            when :symbolic
              SymbolicStyleChecker
            when :numeric
              NumericStyleChecker
            end
          end

          # :nodoc:
          class SymbolicStyleChecker
            class << self
              extend ::RuboCop::NodePattern::Macros

              def_node_matcher :numeric_http_status, <<-PATTERN
                (send nil? :have_http_status $int)
              PATTERN

              def new_from_send_node(send_node)
                node = numeric_http_status(send_node)
                new(node)
              end
            end

            attr_reader :node
            def initialize(node)
              @node = node
            end

            def offensive?
              !node.nil?
            end

            def message
              format(MSG, prefer: preferred_style, current: current_style)
            end

            def preferred_style
              RACK_LOADED ? symbol.inspect : 'symbolic'
            end

            private

            def current_style
              RACK_LOADED ? number.to_s : 'numeric'
            end

            def symbol
              ::Rack::Utils::SYMBOL_TO_STATUS_CODE.key(number)
            end

            def number
              node.source.to_i
            end
          end

          # :nodoc:
          class NumericStyleChecker
            class << self
              extend ::RuboCop::NodePattern::Macros

              def_node_matcher :symbolic_http_status, <<-PATTERN
                (send nil? :have_http_status $sym)
              PATTERN

              def new_from_send_node(send_node)
                node = symbolic_http_status(send_node)
                new(node)
              end
            end

            WHITELIST_STATUS = %i[error success missing redirect].freeze

            attr_reader :node
            def initialize(node)
              @node = node
            end

            def offensive?
              !node.nil? && !WHITELIST_STATUS.include?(node.value)
            end

            def message
              format(MSG, prefer: preferred_style, current: current_style)
            end

            def preferred_style
              RACK_LOADED ? number.to_s : 'numeric'
            end

            private

            def current_style
              RACK_LOADED ? symbol.inspect : 'symbolic'
            end

            def number
              ::Rack::Utils::SYMBOL_TO_STATUS_CODE[symbol]
            end

            def symbol
              node.value
            end
          end
        end
      end
    end
  end
end
