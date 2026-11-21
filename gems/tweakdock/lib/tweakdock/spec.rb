require "yaml"

module TweakDock
  class Error < StandardError; end

  Experiment = Struct.new(:key, :variants, :default, :devices, :group, keyword_init: true) do
    def type_name = Naming.pascal_case(key)
    def property_name = Naming.camel_case(key)
    def all_devices? = devices == Spec::DEVICES
  end

  # The contents of an experiments YAML file.
  Spec = Struct.new(:path, :output, :type_name, :store, :collection, :access, :experiments, keyword_init: true) do
    def output_path = File.expand_path(output, File.dirname(path))
  end

  class Spec
    DEVICES = %w[phone pad mac vision tv].freeze
    SETTINGS = %w[output type store collection group access experiments].freeze
    EXPERIMENT_SETTINGS = %w[variants default devices group].freeze
    KEY = /\A[A-Za-z][A-Za-z0-9_]*\z/

    # Names that TweakDock or the @Tweaks macro already use in the generated type.
    RESERVED_TYPE_NAMES = %w[
      AnyTweak Tweak TweakAction TweakControl TweakCurrentValue TweakDevices TweakPrimitive TweakSource
      TweakStore TweakValue TweakValueProvider Tweaks
    ].freeze
    RESERVED_PROPERTY_NAMES = %w[allTweaks tweakStore].freeze
    # Static members of each variant type.
    RESERVED_VARIANTS = %w[allCases tweakControl].freeze

    def self.load(path)
      document = Psych.parse_file(path)
      check_duplicate_keys(document, path)
      Parser.new(path).parse(YAML.safe_load_file(path))
    rescue Psych::Exception => e
      raise Error, "#{path}: #{e.message}"
    end

    # YAML keeps the last value of a duplicate key, so a copied experiment would hide the first one.
    def self.check_duplicate_keys(node, path)
      if node.is_a?(Psych::Nodes::Mapping)
        keys = node.children.each_slice(2).map(&:first).grep(Psych::Nodes::Scalar).map(&:value)
        duplicate = keys.tally.find { |_, count| count > 1 }
        raise Error, "#{path}: remove the duplicate key #{duplicate.first}." if duplicate
      end
      node.children.to_a.each { |child| check_duplicate_keys(child, path) }
    end
    private_class_method :check_duplicate_keys

    class Parser
      def initialize(path)
        @path = path
      end

      def parse(data)
        fail!("write the settings as a map.") unless data.is_a?(Hash)
        unknown!(data.keys - SETTINGS, "settings")

        output = data["output"]
        fail!("add output, the path of the Swift file.") unless output.is_a?(String) && !output.empty?
        type_name = data.fetch("type", "Experiments").to_s
        fail!("type must be a Swift type name.") unless Naming.identifier?(type_name)
        access = data["access"]
        fail!("access can only be public.") unless access.nil? || access == "public"

        group = data.fetch("group", "A/B Tests").to_s
        entries = data["experiments"]
        fail!("add experiments as a map from each key to its variants.") unless entries.is_a?(Hash) && !entries.empty?

        experiments = entries.map { |key, entry| experiment(key.to_s, entry, group) }
        check_names(experiments)
        Spec.new(path: @path, output: output, type_name: type_name, store: data["store"],
                 collection: data.fetch("collection", "Experiments").to_s, access: access, experiments: experiments)
      end

      private

      def experiment(key, entry, group)
        fail!("#{key}: use letters, digits, and underscores, and start with a letter.") unless KEY.match?(key)

        entry = { "variants" => entry } if entry.is_a?(Array)
        fail!("#{key}: give a list of variants, or a map with variants.") unless entry.is_a?(Hash)
        unknown!(entry.keys - EXPERIMENT_SETTINGS, key)

        variants = variants(key, entry["variants"])
        default = entry.fetch("default", variants.first)
        boolean!(key, default)
        fail!("#{key}: the default #{default} is not in variants.") unless variants.include?(default)

        Experiment.new(key: key, variants: variants, default: default,
                       devices: devices(key, entry["devices"]), group: entry.fetch("group", group).to_s)
      end

      def variants(key, value)
        fail!("#{key}: add variants, for example [A, B].") unless value.is_a?(Array) && !value.empty?

        value.each do |variant|
          boolean!(key, variant)
          fail!("#{key}: the variant #{variant} is not a Swift name.") unless Naming.identifier?(variant.to_s)
          fail!("#{key}: rename the variant #{variant}. The variant type uses it.") if RESERVED_VARIANTS.include?(variant)
        end
        duplicates = value.tally.select { |_, count| count > 1 }.keys
        fail!("#{key}: remove the duplicate variants #{duplicates.join(', ')}.") unless duplicates.empty?
        value.map(&:to_s)
      end

      def devices(key, value)
        names = Array(value || "all").map(&:to_s)
        return DEVICES if names == ["all"]

        unknown = names - DEVICES
        fail!("#{key}: use all, or devices from #{DEVICES.join(', ')}. Remove #{unknown.join(', ')}.") unless unknown.empty?
        fail!("#{key}: add at least one device.") if names.empty?
        DEVICES & names
      end

      def check_names(experiments)
        experiments.each do |experiment|
          if RESERVED_TYPE_NAMES.include?(experiment.type_name)
            fail!("#{experiment.key}: rename it. TweakDock uses the type name #{experiment.type_name}.")
          end
          if RESERVED_PROPERTY_NAMES.include?(experiment.property_name)
            fail!("#{experiment.key}: rename it. @Tweaks uses the name #{experiment.property_name}.")
          end
        end

        %i[type_name property_name].each do |attribute|
          experiments.group_by(&attribute).each do |name, group|
            fail!("#{group.map(&:key).join(' and ')} give the same Swift name #{name}.") if group.size > 1
          end
        end

        peers = experiments.to_h { |experiment| ["#{experiment.property_name}Tweak", experiment] }
        experiments.each do |experiment|
          owner = peers[experiment.property_name]
          fail!("#{experiment.key} gives #{experiment.property_name}, which @Tweak adds for #{owner.key}.") if owner
        end
      end

      def boolean!(key, value)
        return unless [true, false].include?(value)

        fail!("#{key}: put quotes around on, off, yes, and no. YAML reads them as true and false.")
      end

      def unknown!(keys, location)
        fail!("#{location}: remove the unknown keys #{keys.join(', ')}.") unless keys.empty?
      end

      def fail!(message)
        raise Error, "#{@path}: #{message}"
      end
    end
  end
end
