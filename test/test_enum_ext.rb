require 'test_helper'

class EnumExtTest < ActiveSupport::TestCase

  test 'enum_i' do
    EnumI = build_mock_class
    EnumI.enum_i(:test_type)

    EnumI.test_types.each_value do |tt|
      ei = EnumI.create(test_type: tt)
      assert( ei.test_type_i == EnumExtMock.test_types[ei.test_type] )
    end

  end

  test 'ext_enum_sets' do
    EnumSet = build_mock_class

    # instance: raw_level?, high_level?
    # class:
    #   - high_level, raw_level ( as corresponding scopes )
    #   - with_test_types, without_test_types also scopes but with params, allows to combine and negate defined sets and enum values
    #   - raw_level_test_types (= [:unit_test, :spec]), high_level_test_types (=[:view, :controller, :integration])
    #   - raw_level_test_types_i (= [0,1]),  high_level_test_types_i (= [2,3,4])
    #
    # will work correctly only when translate or humanize called
    #   - t_raw_level_test_types, t_high_level_test_types - subset of translation or humanization rules
    #   - t_raw_level_test_types_options, t_high_level_test_types_options - translated options ready for form select inputs
    #   - t_raw_level_test_types_options_i, t_high_level_test_types_options_i - same as above but used integer in selects not strings, usefull in Active Admin
    EnumSet.ext_enum_sets :test_type,
                        raw_level: [:unit_test, :spec],
                        high_level: [:view, :controller, :integration]

    EnumSet.instance_eval do
        ext_enum_sets :test_type,
                      fast: raw_level_test_types | [:controller],
                      minitest: ( raw_level_test_types | high_level_test_types )

    end
    es = EnumSet.create( test_type: :unit_test )

    assert( es.raw_level? )
    assert( !es.high_level? )
    assert( EnumSet.raw_level.exists?( es.id ) )

    assert( EnumSet.raw_level_test_types_i == EnumSet.test_types.slice(:unit_test, :spec).values )
    assert( EnumSet.raw_level_test_types == [:unit_test, :spec] )

    # since translation wasn't defined
    assert( EnumSet.t_raw_level_test_types == [["Enum translations call missed. Did you forget to call translate test_type"]*2].to_h )
    assert( EnumSet.t_raw_level_test_types_options == [["Enum translations call missed. Did you forget to call translate test_type"]*2] )
    assert( EnumSet.t_raw_level_test_types_options_i == [["Enum translations call missed. Did you forget to call translate test_type"]*2] )

    # superset also works
    assert( es.fast? )
    assert( EnumSet.fast.exists?( es.id ) )

  end

  test 'humanize' do
    I18n.locale = :en
    EnumH = build_mock_class
    # adds to instance:
    #  - t_test_types
    #
    # adds to class:
    #  - t_test_types - as given or generated values
    #  - t_test_types_options - translated enum values options for select input
    #  - t_test_types_options_i - same as above but use int values with translations good for ActiveAdmin filter e.t.c.
    EnumH.instance_eval do
      humanize_enum :test_type,
                    unit_test: 'Unit::Test',
                    spec: Proc.new{ I18n.t("activerecord.attributes.enum_ext_test/enum_t.test_types.#{send(:test_type)}")},
                    view: Proc.new{ "View test id: %{id}" % {id: send(:id)} },
                    controller: -> (t_self) { I18n.t("activerecord.attributes.enum_ext_test/enum_t.test_types.#{t_self.test_type}")},
                    integration: -> {'Integration'}
    end

    et = EnumH.create
    et.unit_test!
    assert( et.t_test_type == 'Unit::Test' )

    et.spec!
    assert( et.t_test_type == 'spec tests' )

    et.view!
    assert( et.t_test_type == "View test id: #{et.id}" )

    et.controller!
    assert( et.t_test_type == 'controller tests' )

    assert( EnumH.respond_to?(:t_test_types) )
    assert( EnumH.t_test_types_options == [["Unit::Test", "unit_test"], ["Cannot create option for spec ( proc fails to evaluate )", "spec"],
                                           ["Cannot create option for view ( proc fails to evaluate )", "view"],
                                           ["Cannot create option for controller because of a lambda", "controller"],
                                           ["Integration", "integration"]]
    )
    assert( EnumH.t_test_types_options_i == [["Unit::Test", 0],
                                             ["Cannot create option for spec ( proc fails to evaluate )", 1],
                                             ["Cannot create option for view ( proc fails to evaluate )", 2],
                                             ["Cannot create option for controller because of a lambda", 3],
                                             ["Integration", 4]]
    )

  end

  test 'humanize with block' do
    EnumHB = build_mock_class
    # adds to instance:
    #  - t_test_types
    #
    # adds to class:
    #  - t_test_types - as given or generated values
    #  - t_test_types_options - translated enum values options for select input
    #  - t_test_types_options_i - same as above but use int values with translations good for ActiveAdmin filter e.t.c.
    EnumHB.instance_eval do
      humanize_enum :test_type do
        I18n.t("activerecord.attributes.enum_ext_test/enum_t.test_types.#{test_type}")
      end
    end

    ehb = EnumHB.create

    #locales must change correctly
    I18n.available_locales.each do |locale|
      I18n.locale = locale
      EnumHB.test_types.each_key do |key|
        ehb.send("#{key}!")
        assert( ehb.t_test_type == I18n.t("activerecord.attributes.enum_ext_test/enum_t.test_types.#{ehb.test_type}") )
      end
    end

    I18n.locale = :en
    assert( EnumHB.t_test_types_options == [["unittest", "unit_test"], ["spec tests", "spec"],
                                            ["viewer tests", "view"], ["controller tests", "controller"],
                                            ["integration tests", "integration"]] )

  end


  test 'translate' do
    I18n.locale = :en
    EnumT = build_mock_class
    # adds to instance:
    #  - t_test_types
    #
    # adds to class:
    #  - t_test_types - as given or generated values
    #  - t_test_types_options - translated enum values options for select input
    #  - t_test_types_options_i - same as above but use int values with translations good for ActiveAdmin filter e.t.c.
    EnumT.translate_enum(:test_type)
    et = EnumT.create(test_type: :integration)
    assert( et.t_test_type == 'integration tests' )

    assert( EnumT.respond_to?(:t_test_types) )
    assert( EnumT.t_test_types_options == [["unittest", "unit_test"], ["spec tests", "spec"],
                                           ["viewer tests", "view"], ["controller tests", "controller"],
                                           ["integration tests", "integration"]] )
    assert( EnumT.t_test_types_options_i == [["unittest", 0], ["spec tests", 1],
                                           ["viewer tests", 2], ["controller tests", 3],
                                           ["integration tests", 4]] )

    EnumT.ext_enum_sets :test_type, raw_level: [:unit_test, :spec]

    assert( EnumT.t_raw_level_test_types_options == [["unittest", "unit_test"], ["spec tests", "spec"] ] )
    assert( EnumT.t_raw_level_test_types_options_i == [["unittest", 0], ["spec tests", 1]] )

    # locales must be able change at runtime, not just initialization time
    I18n.locale = :ru
    assert( et.t_test_type == 'Интеграционые тесты' )

    assert( EnumT.respond_to?(:t_test_types) )
    assert( EnumT.t_test_types_options == [["Юнит тест", "unit_test"], ["Спеки", "spec"],
                                           ["Тесты вьюшек ( что конечно перебор )", "view"], ["Контроллер тест", "controller"],
                                           ["Интеграционые тесты", "integration"]] )
    assert( EnumT.t_test_types_options_i == [["Юнит тест", 0], ["Спеки", 1],
                                             ["Тесты вьюшек ( что конечно перебор )", 2], ["Контроллер тест", 3],
                                             ["Интеграционые тесты", 4]] )

    EnumT.ext_enum_sets :test_type, raw_level: [:unit_test, :spec]

    assert( EnumT.t_raw_level_test_types_options == [["Юнит тест", "unit_test"], ["Спеки", "spec"]] )
    assert( EnumT.t_raw_level_test_types_options_i == [["Юнит тест", 0], ["Спеки", 1]] )
  end

  test 'mass assign' do
    EnumMA = EnumExtMock

    # adds class methods with bang: unit_test!, spec! e.t.c
    EnumMA.mass_assign_enum :test_type

    ema = EnumMA.create(test_type: :spec)

    assert( ema.spec? )

    EnumMA.spec.integration!
    assert( EnumMA.integration.exists?( ema.id ) )

    ema_child = ema.enum_ext_mocks.create(test_type: :view)
    assert( ema_child.view? )
    assert( !EnumMA.controller.exists?( ema_child.id ) )

    ema.enum_ext_mocks.controller!
    assert( EnumMA.controller.exists?( ema_child.id ) )
  end
end


