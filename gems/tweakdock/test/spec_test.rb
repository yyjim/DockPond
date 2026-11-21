require_relative "test_helper"

class SpecTest < Minitest::Test
  include SpecFiles

  def test_uses_the_defaults
    spec = load_spec(<<~YAML)
      output: Experiments.swift
      experiments:
        exp_paywall: [A, B]
    YAML

    assert_equal "Experiments", spec.type_name
    assert_nil spec.store
    assert_equal "Experiments", spec.collection
    assert_equal File.join(@dir, "Experiments.swift"), spec.output_path
    experiment = spec.experiments.first
    assert_equal "A", experiment.default
    assert_equal "A/B Tests", experiment.group
    assert experiment.all_devices?
  end

  def test_reads_each_setting
    spec = load_spec(<<~YAML)
      output: Generated/Flags.swift
      type: Flags
      store: .experiments
      collection: Remote
      group: Tests
      access: public
      experiments:
        exp_sidebar:
          variants: [A, B]
          default: B
          devices: [mac, pad]
          group: Lab
    YAML

    assert_equal [File.join(@dir, "Generated/Flags.swift"), "Flags", ".experiments", "Remote", "public"],
                 [spec.output_path, spec.type_name, spec.store, spec.collection, spec.access]
    experiment = spec.experiments.first
    assert_equal ["B", %w[pad mac], "Lab"], [experiment.default, experiment.devices, experiment.group]
  end

  def test_names_the_swift_declarations_from_the_key
    experiment = load_spec("output: E.swift\nexperiments:\n  exp_vip_12m_commitment: [A, B]\n").experiments.first

    assert_equal "ExpVip12mCommitment", experiment.type_name
    assert_equal "expVip12mCommitment", experiment.property_name
  end

  def test_rejects_unquoted_booleans
    assert_spec_error("output: E.swift\nexperiments:\n  exp: [on, off]\n", "put quotes around on, off")
    assert_spec_error("output: E.swift\nexperiments:\n  exp: {variants: ['on', 'off'], default: off}\n",
                      "put quotes around on, off")
  end

  def test_rejects_a_default_that_is_not_a_variant
    assert_spec_error("output: E.swift\nexperiments:\n  exp: {variants: [A, B], default: C}\n",
                      "the default C is not in variants")
  end

  def test_rejects_duplicate_keys
    assert_spec_error("output: E.swift\nexperiments:\n  exp: [A, B]\n  exp: [A, C]\n", "duplicate key exp")
  end

  def test_rejects_unknown_settings
    assert_spec_error("output: E.swift\nexperiments:\n  exp: {variants: [A], defualt: A}\n", "unknown keys defualt")
    assert_spec_error("output: E.swift\nstores: .x\nexperiments:\n  exp: [A]\n", "unknown keys stores")
  end

  def test_rejects_unknown_devices
    assert_spec_error("output: E.swift\nexperiments:\n  exp: {variants: [A], devices: [carplay]}\n",
                      "Remove carplay")
  end

  def test_rejects_names_that_are_not_swift_names
    assert_spec_error("output: E.swift\nexperiments:\n  exp: [A-1]\n", "variant A-1 is not a Swift name")
    assert_spec_error("output: E.swift\nexperiments:\n  1exp: [A]\n", "start with a letter")
    assert_spec_error("output: E.swift\nexperiments:\n  exp: [A, A]\n", "duplicate variants A")
    assert_spec_error("output: E.swift\nexperiments:\n  exp: [A, allCases]\n", "rename the variant allCases")
  end

  def test_rejects_names_that_clash
    assert_spec_error("output: E.swift\nexperiments:\n  exp_a: [A]\n  expA: [A]\n",
                      "exp_a and expA give the same Swift name")
    assert_spec_error("output: E.swift\nexperiments:\n  paywall: [A]\n  paywall_tweak: [A]\n",
                      "which @Tweak adds for paywall")
    assert_spec_error("output: E.swift\nexperiments:\n  all_tweaks: [A]\n", "@Tweaks uses the name allTweaks")
    assert_spec_error("output: E.swift\nexperiments:\n  tweak: [A]\n", "TweakDock uses the type name Tweak")
  end

  def test_requires_output_and_experiments
    assert_spec_error("experiments:\n  exp: [A]\n", "add output")
    assert_spec_error("output: E.swift\n", "add experiments")
  end
end
