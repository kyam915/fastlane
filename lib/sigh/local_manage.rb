module Sigh
  class LocalManage
    LIST = "list"
    CLEANUP = "cleanup"

    def self.start(options, args)
      command, clean_expired, clean_pattern = get_inputs(options, args)
      if command == LIST
        list_profiles
      elsif command == CLEANUP
        cleanup_profiles(clean_expired, clean_pattern)
      end
    end

    def self.install_profile(profile)
      UI.message "Installing provisioning profile..."
      profile_path = File.expand_path("~") + "/Library/MobileDevice/Provisioning Profiles/"
      profile_filename = ENV["SIGH_UDID"] + ".mobileprovision"
      destination = profile_path + profile_filename

      # If the directory doesn't exist, make it first
      unless File.directory?(profile_path)
        FileUtils.mkdir_p(profile_path)
      end

      # copy to Xcode provisioning profile directory
      FileUtils.copy profile, destination

      if File.exist? destination
        UI.success "Profile installed at \"#{destination}\""
      else
        UI.user_error!("Failed installation of provisioning profile at location: #{destination}")
      end
    end

    def self.get_inputs(options, _args)
      clean_expired = options.clean_expired
      clean_pattern = /#{options.clean_pattern}/ if options.clean_pattern
      command = (!clean_expired.nil? || !clean_pattern.nil?) ? CLEANUP : LIST
      return command, clean_expired, clean_pattern
    end

    def self.list_profiles
      profiles = load_profiles

      now = DateTime.now
      soon = (Date.today + 30).to_datetime

      profiles_valid = profiles.select { |profile| profile["ExpirationDate"] > now && profile["ExpirationDate"] > soon }
      if profiles_valid.count > 0
        UI.message "Provisioning profiles installed"
        UI.message "Valid:"
        profiles_valid.each do |profile|
          UI.message profile["Name"].green
        end
      end

      profiles_soon = profiles.select { |profile| profile["ExpirationDate"] > now && profile["ExpirationDate"] < soon }
      if profiles_soon.count > 0
        UI.message ""
        UI.message "Expiring within 30 day:"
        profiles_soon.each do |profile|
          UI.message profile["Name"].yellow
        end
      end

      profiles_expired = profiles.select { |profile| profile["ExpirationDate"] < now }
      if profiles_expired.count > 0
        UI.message ""
        UI.message "Expired:"
        profiles_expired.each do |profile|
          UI.message profile["Name"].red
        end
      end

      UI.message ""
      UI.message "Summary"
      UI.message "#{profiles.count} installed profiles"
      UI.message "#{profiles_expired.count} are expired".red
      UI.message "#{profiles_soon.count} are valid but will expire within 30 days".yellow
      UI.message "#{profiles_valid.count} are valid".green

      UI.message "You can remove all expired profiles using `sigh manage -e`" if profiles_expired.count > 0
    end

    def self.cleanup_profiles(expired = false, pattern = nil)
      now = DateTime.now

      profiles = load_profiles.select { |profile| (expired && profile["ExpirationDate"] < now) || (!pattern.nil? && profile["Name"] =~ pattern) }

      UI.message "The following provisioning profiles are either expired or matches your pattern:"
      profiles.each do |profile|
        UI.message profile["Name"].red
      end

      if agree("Delete these provisioning profiles #{profiles.length}? (y/n)  ", true)
        profiles.each do |profile|
          File.delete profile["Path"]
        end
        UI.success "\n\nDeleted #{profiles.length} profiles"
      end
    end

    def self.load_profiles
      UI.message "Loading Provisioning profiles from ~/Library/MobileDevice/Provisioning Profiles/"
      profiles_path = File.expand_path("~") + "/Library/MobileDevice/Provisioning Profiles/*.mobileprovision"
      profile_paths = Dir[profiles_path]

      profiles = []
      profile_paths.each do |profile_path|
        profile = Plist.parse_xml(`security cms -D -i '#{profile_path}'`)
        profile['Path'] = profile_path
        profiles << profile
      end

      profiles = profiles.sort_by { |profile| profile["Name"].downcase }

      return profiles
    end
  end
end