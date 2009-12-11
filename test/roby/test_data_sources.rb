BASE_DIR = File.expand_path( '../..', File.dirname(__FILE__))
APP_DIR = File.join(BASE_DIR, "test")

$LOAD_PATH.unshift BASE_DIR
require 'test/roby/common'

class TC_RobySpec_DataSourceModels < Test::Unit::TestCase
    include RobyPluginCommonTest

    needs_no_orogen_projects

    def test_data_source_type
        model = sys_model.data_source_type("image")
        assert_kind_of(DataSourceModel, model)
        assert(model < DataSource)

        assert_equal("image", model.name)
        assert_equal("#<DataSource: image>", model.to_s)
        assert_same(model, Roby.app.orocos_data_sources["image"])
    end

    def test_data_source_task_model
        model = sys_model.data_source_type("image")
        task  = model.task_model
        assert_same(task, model.task_model)
        assert(task.fullfills?(model))
    end

    def test_data_source_submodel
        parent_model = sys_model.data_source_type("test")
        model = sys_model.data_source_type("image", :parent_model => "test")
        assert_same(model, Roby.app.orocos_data_sources["image"])
        assert_kind_of(DataSourceModel, model)
        assert(model < parent_model)
    end

    def test_data_source_interface_name
        Roby.app.load_orogen_project "system_test"
        model = sys_model.data_source_type("camera", :interface => "system_test::CameraDriver")
        assert_same(SystemTest::CameraDriver.orogen_spec, model.task_model.orogen_spec)
    end

    def test_data_source_interface_model
        Roby.app.load_orogen_project "system_test"
        model = sys_model.data_source_type("camera", :interface => SystemTest::CameraDriver)
        assert_same(SystemTest::CameraDriver.orogen_spec, model.task_model.orogen_spec)
    end

    def test_device_type
        model = sys_model.device_type("camera")
        assert_same(model, Roby.app.orocos_devices["camera"])
        assert_equal("camera", model.name)
        assert_equal("#<DeviceDriver: camera>", model.to_s)
        assert(data_source = Roby.app.orocos_data_sources["camera"])
        assert(data_source != model)

        assert(model < data_source)
        assert(model < DeviceDriver)
        assert(model < DataSource)
    end

    def test_device_type_reuses_data_source
        source = sys_model.data_source_type("camera")
        model  = sys_model.device_type("camera")
        assert_same(source, Roby.app.orocos_data_sources['camera'])
    end

    def test_device_type_disabled_provides
        sys_model.device_type("camera", :provides => nil)
        assert(!Roby.app.orocos_data_sources['camera'])
    end

    def test_device_type_explicit_provides_as_object
        source = sys_model.data_source_type("image")
        model  = sys_model.device_type("camera", :provides => source)
        assert(model < source)
        assert(! Roby.app.orocos_data_sources['camera'])
    end

    def test_device_type_explicit_provides_as_string
        source = sys_model.data_source_type("image")
        model  = sys_model.device_type("camera", :provides => 'image')
        assert(model < source)
        assert(! Roby.app.orocos_data_sources['camera'])
    end


    def test_task_data_source_declaration_default_name
        source_model = sys_model.data_source_type 'image'
        task_model   = Class.new(TaskContext) do
            data_source 'image'
        end
        assert_raises(SpecError) { task_model.data_source('image') }

        assert(task_model.has_data_source?('image'))
        assert(task_model.main_data_source?('image'))

        assert(task_model < source_model)
        assert_equal(source_model, task_model.data_source_type('image'))
        assert_equal([["image", source_model]], task_model.each_root_data_source.to_a)
        assert_equal([:image_name], task_model.arguments.to_a)
    end

    def test_task_data_source_declaration_specific_name
        source_model = sys_model.data_source_type 'image'
        task_model   = Class.new(TaskContext) do
            data_source 'image', :as => 'left_image'
        end
        assert_raises(SpecError) { task_model.data_source('image', :as => 'left_image') }

        assert(!task_model.has_data_source?('image'))
        assert(task_model.has_data_source?('left_image'))
        assert_raises(ArgumentError) { task_model.data_source_type('image') }

        assert(task_model.fullfills?(source_model))
        assert_equal(source_model, task_model.data_source_type('left_image'))
        assert_equal([["left_image", source_model]], task_model.each_root_data_source.to_a)
        assert_equal([:left_image_name], task_model.arguments.to_a)
    end

    def test_task_data_source_specific_model
        source_model = sys_model.data_source_type 'image'
        other_source = sys_model.data_source_type 'image2'
        task_model   = Class.new(TaskContext) do
            data_source 'image', :as => 'left_image', :model => other_source
        end
        assert_same(other_source, task_model.data_source_type('left_image'))
        assert(!(task_model < source_model))
        assert(task_model < other_source)
    end

    def test_task_data_source_declaration_inheritance
        source_model = sys_model.data_source_type 'image'
        parent_model   = Class.new(TaskContext) do
            data_source 'image', :as => 'left_image'
        end
        task_model = Class.new(parent_model)
        assert_raises(SpecError) { task_model.data_source('image', :as => 'left_image') }

        assert(task_model.has_data_source?('left_image'))

        assert(task_model.fullfills?(source_model))
        assert_equal(source_model, task_model.data_source_type('left_image'))
        assert_equal([["left_image", source_model]], task_model.each_root_data_source.to_a)
    end

    def test_task_data_source_overriden_by_device_driver
        source_model = sys_model.data_source_type 'image'
        driver_model = sys_model.device_type 'camera', :provides => 'image'

        parent_model   = Class.new(TaskContext) do
            data_source 'image', :as => 'left_image'
        end
        task_model = Class.new(parent_model)
        task_model.driver_for('camera', :as => 'left_image')

        assert(task_model.has_data_source?('left_image'))

        assert(task_model.fullfills?(source_model))
        assert(task_model.fullfills?(driver_model))
        assert_equal(driver_model, task_model.data_source_type('left_image'))
        assert_equal([["left_image", driver_model]], task_model.each_data_source.to_a)
        assert_equal([["left_image", driver_model]], task_model.each_root_data_source.to_a)
    end

    def test_slave_data_source_declaration
        stereo_model = sys_model.data_source_type 'stereocam'
        image_model  = sys_model.data_source_type 'image'
        task_model   = Class.new(TaskContext) do
            data_source 'stereocam', :as => 'stereo'
            data_source 'image', :as => 'left_image', :slave_of => 'stereo'
            data_source 'image', :as => 'right_image', :slave_of => 'stereo'
        end

        assert_raises(SpecError) { task_model.data_source 'image', :slave_of => 'bla' }

        assert(task_model.fullfills?(image_model))
        assert_equal(image_model, task_model.data_source_type('stereo.left_image'))
        assert_equal(image_model, task_model.data_source_type('stereo.right_image'))
        assert_equal([["left_image", image_model], ["right_image", image_model]].to_set, task_model.each_child_data_source('stereo').to_set)

        expected = [
            ["stereo", stereo_model],
            ["stereo.left_image", image_model],
            ["stereo.right_image", image_model]
        ]
        assert_equal(expected.to_set, task_model.each_data_source.to_set)
        assert_equal([["stereo", stereo_model]], task_model.each_root_data_source.to_a)
        assert_equal([:stereo_name], task_model.arguments.to_a)
    end

    def test_data_source_find_matching_source
        stereo_model = sys_model.data_source_type 'stereocam'
        image_model  = sys_model.data_source_type 'image'
        task_model   = Class.new(TaskContext) do
            data_source 'stereocam', :as => 'stereo'
            data_source 'image', :as => 'left',  :slave_of => 'stereo'
            data_source 'image', :as => 'right', :slave_of => 'stereo'
        end

        assert_equal "stereo",     task_model.find_matching_source(stereo_model)
        assert_raises(Ambiguous) { task_model.find_matching_source(image_model) }
        assert_equal "stereo.left", task_model.find_matching_source(image_model, "left")
        assert_equal "stereo.left", task_model.find_matching_source(image_model, "stereo.left")

        # Add fakes to trigger disambiguation by main/non-main
        task_model.data_source 'image', :as => 'left'
        assert_equal "left", task_model.find_matching_source(image_model)
        task_model.data_source 'image', :as => 'right'
        assert_raises(Ambiguous) { task_model.find_matching_source(image_model) }
        assert_equal "left", task_model.find_matching_source(image_model, "left")
        assert_equal "stereo.left", task_model.find_matching_source(image_model, "stereo.left")
    end

    def test_data_source_instance
        stereo_model = sys_model.data_source_type 'stereocam'
        task_model   = Class.new(TaskContext) do
            data_source 'stereocam', :as => 'stereo'
        end
        task = task_model.new 'stereo_name' => 'front_stereo'

        assert_equal("front_stereo", task.selected_data_source('stereo'))
        assert_equal(stereo_model, task.data_source_type('front_stereo'))
    end

    def test_data_source_can_merge
        Roby.app.load_orogen_project 'system_test'
        task_model = SystemTest::StereoProcessing

        stereo_model = sys_model.data_source_type 'stereocam', :interface => SystemTest::Stereo
        task_model.data_source 'stereocam', :as => 'stereo'

        plan.add(parent = Roby::Task.new)
        task0 = task_model.new 'stereo_name' => 'front_stereo'
        task1 = task_model.new
        parent.depends_on task0, :model => Roby.app.orocos_data_sources['stereocam']
        parent.depends_on task1, :model => Roby.app.orocos_data_sources['stereocam']

        assert(task0.can_merge?(task1))
        assert(task1.can_merge?(task0))

        task1.stereo_name = 'back_stereo'
        assert(!task0.can_merge?(task1))
        assert(!task1.can_merge?(task0))
    end

    def test_using_data_source
        Roby.app.load_orogen_project 'system_test'

        stereo_model = sys_model.data_source_type 'stereocam', :interface => SystemTest::StereoProcessing
        camera_model = sys_model.data_source_type 'camera', :interface => SystemTest::CameraDriver
        SystemTest::StereoProcessing.data_source 'stereocam'
        SystemTest::CameraDriver.data_source 'camera'

        plan.add(stereo = SystemTest::StereoProcessing.new)
        assert(!stereo.using_data_source?('stereocam'))

        plan.add(camera = SystemTest::CameraDriver.new)
        camera.add_sink stereo, [['image', 'image0', {}]]
        assert(camera.using_data_source?('camera'))
        assert(stereo.using_data_source?('stereocam'))

        plan.remove_object(camera)
        plan.add(dem = SystemTest::DemBuilder.new)
        assert(!stereo.using_data_source?('stereocam'))
        stereo.add_sink dem, [['cloud', 'cloud', {}]]
        assert(stereo.using_data_source?('stereocam'))
    end

    def test_data_source_merge_data_flow
        Roby.app.load_orogen_project 'system_test'

        sys_model.data_source_type 'camera', :interface => SystemTest::CameraDriver
        sys_model.data_source_type 'stereo', :interface => SystemTest::Stereo
        SystemTest::StereoCamera.class_eval do
            data_source 'stereo'
            data_source 'camera', :as => 'left', :slave_of => 'stereo'
            data_source 'camera', :as => 'right', :slave_of => 'stereo'
        end
        stereo_model = SystemTest::StereoCamera

        SystemTest::CameraDriver.class_eval do
            data_source 'camera'
        end
        camera_model = Roby.app.orocos_data_sources['camera'].task_model

        plan.add(parent = Roby::Task.new)
        task0 = stereo_model.new 'stereo_name' => 'front_stereo'
        task1 = camera_model.new 'camera_name' => 'front_stereo.left'
        parent.depends_on task0, :model => Roby.app.orocos_data_sources['camera']
        parent.depends_on task1, :model => Roby.app.orocos_data_sources['camera']

        assert(task0.can_merge?(task1))
        assert(!task1.can_merge?(task0))
        # Complex merge of data flow is actually not implemented. Make sure we
        # won't do anything stupid and clearly tell that to the user.
        assert_raises(NotImplementedError) { task0.merge(task1) }
    end

    def test_data_source_merge_arguments
        Roby.app.load_orogen_project 'system_test'

        stereo_model = sys_model.data_source_type 'camera', :interface => SystemTest::CameraDriver
        stereo_model = sys_model.data_source_type 'stereo', :interface => SystemTest::Stereo
        SystemTest::StereoCamera.class_eval do
            data_source 'stereo'
            data_source 'camera', :as => 'left', :slave_of => 'stereo'
            data_source 'camera', :as => 'right', :slave_of => 'stereo'
        end
        task_model = SystemTest::StereoCamera

        plan.add(parent = Roby::Task.new)
        task0 = task_model.new 'stereo_name' => 'front_stereo'
        task1 = task_model.new
        parent.depends_on task0, :model => Roby.app.orocos_data_sources['stereo']
        parent.depends_on task1, :model => Roby.app.orocos_data_sources['stereo']

        task0.merge(task1)
        assert_equal({ :stereo_name => "front_stereo" }, task0.arguments)

        plan.add(parent = Roby::Task.new)
        task0 = task_model.new 'stereo_name' => 'front_stereo'
        task1 = task_model.new
        parent.depends_on task0, :model => Roby.app.orocos_data_sources['stereo']
        parent.depends_on task1, :model => Roby.app.orocos_data_sources['stereo']

        task1.merge(task0)
        assert_equal({ :stereo_name => "front_stereo" }, task1.arguments)
    end

    def test_slave_data_source_instance
        stereo_model = sys_model.data_source_type 'stereocam'
        image_model  = sys_model.data_source_type 'image'
        task_model   = Class.new(TaskContext) do
            data_source 'stereocam', :as => 'stereo'
            data_source 'image', :as => 'left', :slave_of => 'stereo'
            data_source 'image', :as => 'right', :slave_of => 'stereo'
        end
        task = task_model.new 'stereo_name' => 'front_stereo'

        assert_equal("front_stereo", task.selected_data_source('stereo'))
        assert_equal("front_stereo.left", task.selected_data_source('stereo.left'))
        assert_equal("front_stereo.right", task.selected_data_source('stereo.right'))
        assert_equal(stereo_model, task.data_source_type('front_stereo'))
        assert_equal(image_model, task.data_source_type("front_stereo.left"))
        assert_equal(image_model, task.data_source_type("front_stereo.right"))
    end

    def test_driver_for
        image_model  = sys_model.data_source_type 'image'
        device_model = sys_model.device_type 'camera', :provides => 'image'
        device_driver = Class.new(TaskContext) do
            driver_for 'camera'
        end

        assert(device_driver.fullfills?(device_model))
        assert(device_driver < image_model)
        assert(device_driver.fullfills?(image_model))
        assert(device_driver.has_data_source?('camera'))
        assert_equal(device_model, device_driver.data_source_type('camera'))
    end

    def test_driver_for_unknown_device_type
        sys_model.data_source_type 'camera'
        model = Class.new(TaskContext)
        assert_raises(ArgumentError) do
            model.driver_for 'camera'
        end
    end
end

