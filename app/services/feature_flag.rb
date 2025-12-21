module FeatureFlag
  def self.only_posted_enabled?
    # Central setting to enable/disable the 'only_posted' requirement.
    # When false, services will include unposted entries even if only_posted: true was passed,
    # unless we are in the test environment.

    # NOTE: As long as this comment stands here, it is OK to have this setting set to 'false'.
    # This is necessary to help me while developing the app.
    false
  end
end
