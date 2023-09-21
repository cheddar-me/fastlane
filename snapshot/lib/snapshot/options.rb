require 'fastlane_core/configuration/config_item'
require 'fastlane_core/device_manager'
require 'fastlane/helper/xcodebuild_formatter_helper'
require 'credentials_manager/appfile_config'
require_relative 'module'

module Snapshot
  class Options
    def self.verify_type(item_name, acceptable_types, value)
      type_ok = [Array, String].any? { |type| value.kind_of?(type) }
      UI.user_error!("'#{item_name}' should be of type #{acceptable_types.join(' or ')} but found: #{value.class.name}") unless type_ok
    end

    def self.available_options
      @options ||= plain_options
    end

    def self.plain_options
      output_directory = (File.directory?("fastlane") ? "fastlane/screenshots" : "screenshots")

      [
        FastlaneCore::ConfigItem.new(key: :workspace,
                                     short_option: "-w",
                                     env_name: "SNAPSHOT_WORKSPACE",
                                     optional: true,
                                     description: "Path the workspace file",
                                     verify_block: proc do |value|
                                       v = File.expand_path(value.to_s)
                                       UI.user_error!("Workspace file not found at path '#{v}'") unless File.exist?(v)
                                       UI.user_error!("Workspace file invalid") unless File.directory?(v)
                                       UI.user_error!("Workspace file is not a workspace, must end with .xcworkspace") unless v.include?(".xcworkspace")
                                     end),
        FastlaneCore::ConfigItem.new(key: :project,
                                     short_option: "-p",
                                     optional: true,
                                     env_name: "SNAPSHOT_PROJECT",
                                     description: "Path the project file",
                                     verify_block: proc do |value|
                                       v = File.expand_path(value.to_s)
                                       UI.user_error!("Project file not found at path '#{v}'") unless File.exist?(v)
                                       UI.user_error!("Project file invalid") unless File.directory?(v)
                                       UI.user_error!("Project file is not a project file, must end with .xcodeproj") unless v.include?(".xcodeproj")
                                     end),
        FastlaneCore::ConfigItem.new(key: :xcargs,
                                     short_option: "-X",
                                     env_name: "SNAPSHOT_XCARGS",
                                     description: "Pass additional arguments to xcodebuild for the test phase. Be sure to quote the setting names and values e.g. OTHER_LDFLAGS=\"-ObjC -lstdc++\"",
                                     optional: true,
                                     type: :shell_string),
        FastlaneCore::ConfigItem.new(key: :xcconfig,
                                     short_option: "-y",
                                     env_name: "SNAPSHOT_XCCONFIG",
                                     description: "Use an extra XCCONFIG file to build your app",
                                     optional: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("File not found at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                     end),
        FastlaneCore::ConfigItem.new(key: :devices,
                                     description: "A list of devices you want to take the screenshots from",
                                     short_option: "-d",
                                     type: Array,
                                     optional: true,
                                     verify_block: proc do |value|
                                       available = FastlaneCore::DeviceManager.simulators
                                       value.each do |current|
                                         device = current.strip
                                         unless available.any? { |d| d.name.strip == device } || device == "Mac"
                                           UI.user_error!("Device '#{device}' not in list of available simulators '#{available.join(', ')}'")
                                         end
                                       end
                                     end),
        FastlaneCore::ConfigItem.new(key: :languages,
                                     description: "A list of languages which should be used",
                                     short_option: "-g",
                                     type: Array,
                                     default_value: ['en-US']),
        FastlaneCore::ConfigItem.new(key: :launch_arguments,
                                     env_name: 'SNAPSHOT_LAUNCH_ARGUMENTS',
                                     description: "A list of launch arguments which should be used",
                                     short_option: "-m",
                                     type: Array,
                                     default_value: ['']),
        FastlaneCore::ConfigItem.new(key: :output_directory,
                                     short_option: "-o",
                                     env_name: "SNAPSHOT_OUTPUT_DIRECTORY",
                                     description: "The directory where to store the screenshots",
                                     default_value: output_directory,
                                     default_value_dynamic: true),
        FastlaneCore::ConfigItem.new(key: :output_simulator_logs,
                                     env_name: "SNAPSHOT_OUTPUT_SIMULATOR_LOGS",
                                     description: "If the logs generated by the app (e.g. using NSLog, perror, etc.) in the Simulator should be written to the output_directory",
                                     type: Boolean,
                                     default_value: false,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :ios_version,
                                     description: "By default, the latest version should be used automatically. If you want to change it, do it here",
                                     short_option: "-i",
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :skip_open_summary,
                                     env_name: 'SNAPSHOT_SKIP_OPEN_SUMMARY',
                                     description: "Don't open the HTML summary after running _snapshot_",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :skip_helper_version_check,
                                     env_name: 'SNAPSHOT_SKIP_SKIP_HELPER_VERSION_CHECK',
                                     description: "Do not check for most recent SnapshotHelper code",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :clear_previous_screenshots,
                                     env_name: 'SNAPSHOT_CLEAR_PREVIOUS_SCREENSHOTS',
                                     description: "Enabling this option will automatically clear previously generated screenshots before running snapshot",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :reinstall_app,
                                     env_name: 'SNAPSHOT_REINSTALL_APP',
                                     description: "Enabling this option will automatically uninstall the application before running it",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :erase_simulator,
                                     env_name: 'SNAPSHOT_ERASE_SIMULATOR',
                                     description: "Enabling this option will automatically erase the simulator before running the application",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :headless,
                                     env_name: 'SNAPSHOT_HEADLESS',
                                     description: "Enabling this option will prevent displaying the simulator window",
                                     default_value: true,
                                     type: Boolean),
        FastlaneCore::ConfigItem.new(key: :override_status_bar,
                                     env_name: 'SNAPSHOT_OVERRIDE_STATUS_BAR',
                                     description: "Enabling this option will automatically override the status bar to show 9:41 AM, full battery, and full reception (Adjust 'SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT' environment variable if override status bar is not working. Might be because simulator is not fully booted. Defaults to 10 seconds)",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :override_status_bar_arguments,
                                     env_name: 'SNAPSHOT_OVERRIDE_STATUS_BAR_ARGUMENTS',
                                     description: "Fully customize the status bar by setting each option here. Requires `override_status_bar` to be set to `true`. See `xcrun simctl status_bar --help`",
                                     optional: true,
                                     type: String),
        FastlaneCore::ConfigItem.new(key: :localize_simulator,
                                     env_name: 'SNAPSHOT_LOCALIZE_SIMULATOR',
                                     description: "Enabling this option will configure the Simulator's system language",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :dark_mode,
                                    env_name: 'SNAPSHOT_DARK_MODE',
                                    description: "Enabling this option will configure the Simulator to be in dark mode (false for light, true for dark)",
                                    optional: true,
                                    type: Boolean),
        FastlaneCore::ConfigItem.new(key: :app_identifier,
                                     env_name: 'SNAPSHOT_APP_IDENTIFIER',
                                     short_option: "-a",
                                     optional: true,
                                     description: "The bundle identifier of the app to uninstall (only needed when enabling reinstall_app)",
                                     code_gen_sensitive: true,
                                     # This incorrect env name is here for backwards compatibility
                                     default_value: ENV["SNAPSHOT_APP_IDENTITIFER"] || CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
                                     default_value_dynamic: true),
        FastlaneCore::ConfigItem.new(key: :add_photos,
                                     env_name: 'SNAPSHOT_PHOTOS',
                                     short_option: "-j",
                                     description: "A list of photos that should be added to the simulator before running the application",
                                     type: Array,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :add_videos,
                                     env_name: 'SNAPSHOT_VIDEOS',
                                     short_option: "-u",
                                     description: "A list of videos that should be added to the simulator before running the application",
                                     type: Array,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :html_template,
                                     env_name: 'SNAPSHOT_HTML_TEMPLATE',
                                     short_option: "-e",
                                     description: "A path to screenshots.html template",
                                     optional: true),

        # Everything around building
        FastlaneCore::ConfigItem.new(key: :buildlog_path,
                                     short_option: "-l",
                                     env_name: "SNAPSHOT_BUILDLOG_PATH",
                                     description: "The directory where to store the build log",
                                     default_value: "#{FastlaneCore::Helper.buildlog_path}/snapshot",
                                     default_value_dynamic: true),
        FastlaneCore::ConfigItem.new(key: :clean,
                                     short_option: "-c",
                                     env_name: "SNAPSHOT_CLEAN",
                                     description: "Should the project be cleaned before building it?",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :test_without_building,
                                     short_option: "-T",
                                     env_name: "SNAPSHOT_TEST_WITHOUT_BUILDING",
                                     description: "Test without building, requires a derived data path",
                                     is_string: false,
                                     type: Boolean,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :configuration,
                                     short_option: "-q",
                                     env_name: "SNAPSHOT_CONFIGURATION",
                                     description: "The configuration to use when building the app. Defaults to 'Release'",
                                     default_value_dynamic: true,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :sdk,
                                     short_option: "-k",
                                     env_name: "SNAPSHOT_SDK",
                                     description: "The SDK that should be used for building the application",
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :scheme,
                                     short_option: "-s",
                                     env_name: 'SNAPSHOT_SCHEME',
                                     description: "The scheme you want to use, this must be the scheme for the UI Tests",
                                     optional: true), # optional true because we offer a picker to the user
        FastlaneCore::ConfigItem.new(key: :number_of_retries,
                                     short_option: "-n",
                                     env_name: 'SNAPSHOT_NUMBER_OF_RETRIES',
                                     description: "The number of times a test can fail before snapshot should stop retrying",
                                     type: Integer,
                                     default_value: 1),
        FastlaneCore::ConfigItem.new(key: :stop_after_first_error,
                                     env_name: 'SNAPSHOT_BREAK_ON_FIRST_ERROR',
                                     description: "Should snapshot stop immediately after the tests completely failed on one device?",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :derived_data_path,
                                     short_option: "-f",
                                     env_name: "SNAPSHOT_DERIVED_DATA_PATH",
                                     description: "The directory where build products and other derived data will go",
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :result_bundle,
                                     short_option: "-z",
                                     env_name: "SNAPSHOT_RESULT_BUNDLE",
                                     is_string: false,
                                     description: "Should an Xcode result bundle be generated in the output directory",
                                     default_value: false,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :test_target_name,
                                     env_name: "SNAPSHOT_TEST_TARGET_NAME",
                                     description: "The name of the target you want to test (if you desire to override the Target Application from Xcode)",
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :namespace_log_files,
                                     env_name: "SNAPSHOT_NAMESPACE_LOG_FILES",
                                     description: "Separate the log files per device and per language",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :concurrent_simulators,
                                     env_name: "SNAPSHOT_EXECUTE_CONCURRENT_SIMULATORS",
                                     description: "Take snapshots on multiple simulators concurrently. Note: This option is only applicable when running against Xcode 9",
                                     default_value: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :disable_slide_to_type,
                                     env_name: "SNAPSHOT_DISABLE_SLIDE_TO_TYPE",
                                     description: "Disable the simulator from showing the 'Slide to type' prompt",
                                     default_value: false,
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :cloned_source_packages_path,
                                     env_name: "SNAPSHOT_CLONED_SOURCE_PACKAGES_PATH",
                                     description: "Sets a custom path for Swift Package Manager dependencies",
                                     type: String,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :skip_package_dependencies_resolution,
                                     env_name: "SNAPSHOT_SKIP_PACKAGE_DEPENDENCIES_RESOLUTION",
                                     description: "Skips resolution of Swift Package Manager dependencies",
                                     type: Boolean,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :disable_package_automatic_updates,
                                     env_name: "SNAPSHOT_DISABLE_PACKAGE_AUTOMATIC_UPDATES",
                                     description: "Prevents packages from automatically being resolved to versions other than those recorded in the `Package.resolved` file",
                                     type: Boolean,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :testplan,
                                     env_name: "SNAPSHOT_TESTPLAN",
                                     description: "The testplan associated with the scheme that should be used for testing",
                                     is_string: true,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :only_testing,
                                     env_name: "SNAPSHOT_ONLY_TESTING",
                                     description: "Array of strings matching Test Bundle/Test Suite/Test Cases to run",
                                     optional: true,
                                     is_string: false,
                                     verify_block: proc do |value|
                                       verify_type('only_testing', [Array, String], value)
                                     end),
        FastlaneCore::ConfigItem.new(key: :skip_testing,
                                     env_name: "SNAPSHOT_SKIP_TESTING",
                                     description: "Array of strings matching Test Bundle/Test Suite/Test Cases to skip",
                                     optional: true,
                                     is_string: false,
                                     verify_block: proc do |value|
                                       verify_type('skip_testing', [Array, String], value)
                                     end),

        FastlaneCore::ConfigItem.new(key: :xcodebuild_formatter,
                                     env_names: ["SNAPSHOT_XCODEBUILD_FORMATTER", "FASTLANE_XCODEBUILD_FORMATTER"],
                                     description: "xcodebuild formatter to use (ex: 'xcbeautify', 'xcbeautify --quieter', 'xcpretty', 'xcpretty -test'). Use empty string (ex: '') to disable any formatter (More information: https://docs.fastlane.tools/best-practices/xcodebuild-formatters/)",
                                     type: String,
                                     default_value: Fastlane::Helper::XcodebuildFormatterHelper.xcbeautify_installed? ? 'xcbeautify' : 'xcpretty',
                                     default_value_dynamic: true),

        # xcpretty
        FastlaneCore::ConfigItem.new(key: :xcpretty_args,
                                     short_option: "-x",
                                     env_name: "SNAPSHOT_XCPRETTY_ARGS",
                                     deprecated: "Use `xcodebuild_formatter: ''` instead",
                                     description: "Additional xcpretty arguments",
                                     is_string: true,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :disable_xcpretty,
                                     env_name: "SNAPSHOT_DISABLE_XCPRETTY",
                                     description: "Disable xcpretty formatting of build",
                                     type: Boolean,
                                     optional: true),

        FastlaneCore::ConfigItem.new(key: :suppress_xcode_output,
                                     env_name: "SNAPSHOT_SUPPRESS_XCODE_OUTPUT",
                                     description: "Suppress the output of xcodebuild to stdout. Output is still saved in buildlog_path",
                                     type: Boolean,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :use_system_scm,
                                     env_name: "SNAPSHOT_USE_SYSTEM_SCM",
                                     description: "Lets xcodebuild use system's scm configuration",
                                     type: Boolean,
                                     default_value: false)
      ]
    end
  end
end
