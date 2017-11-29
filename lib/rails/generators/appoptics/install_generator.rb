# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a AppOptics gem initializer file to your application."

    @namespace = "appoptics:install"

    def copy_initializer
      # Set defaults
      @verbose = 'false'

      print_header
      print_footer

      template "appoptics_initializer.rb", "config/initializers/appoptics.rb"
    end

    private

      def print_header
        say ""
        say shell.set_color "Welcome to the AppOptics Ruby instrumentation setup.", :green, :bold
        say ""
        say shell.set_color "Documentation Links", :magenta
        say "-------------------"
        say ""
        say "AppOptics Installation Overview:"
        say "http://docs.appoptics.solarwinds.com/AppOptics/install-instrumentation.html"
        say ""
        say "More information on instrumenting Ruby applications can be found here:"
        say "http://docs.appoptics.solarwinds.com/Instrumentation/ruby.html#installing-ruby-instrumentation"
      end

      def print_footer
        say ""
        say "You can change configuration values in the future by modifying config/initializers/appoptics.rb"
        say ""
        say "Thanks! Creating the AppOptics initializer..."
        say ""
      end
  end
end