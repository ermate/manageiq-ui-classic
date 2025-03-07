require 'miq_bulk_import'

class ConfigurationController < ApplicationController
  include StartUrl
  include Mixins::GenericSessionMixin
  include Mixins::BreadcrumbsMixin

  logo_dir = File.expand_path(Rails.root.join('public', 'upload'))
  Dir.mkdir(logo_dir) unless File.exist?(logo_dir)

  VIEW_RESOURCES = DEFAULT_SETTINGS[:views].keys.each_with_object({}) { |value, acc| acc[value.to_s] = value }.freeze

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def title
    _("My Settings")
  end

  def index
    @breadcrumbs = []
    active_tab = nil
    if role_allows?(:feature => "my_settings_visuals")
      active_tab = 1 if active_tab.nil?
    elsif role_allows?(:feature => "my_settings_default_filters")
      active_tab = 3 if active_tab.nil?
    elsif role_allows?(:feature => "my_settings_time_profiles")
      active_tab = 4 if active_tab.nil?
    end
    @tabform = params[:load_edit_err] ? @tabform : "ui_#{active_tab}"
    edit
    render :action => "show"
  end

  # handle buttons pressed on the button bar
  def button
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    timeprofile_delete if params[:pressed] == "tp_delete"
    copy_record if params[:pressed] == "tp_copy"
    edit_record if params[:pressed] == "tp_edit"

    if !@refresh_partial && @flash_array.nil? # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit", "_copy")
      javascript_redirect(:action => @refresh_partial, :id => @redirect_id)
    else
      build_tabs
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << "miqScrollTop();" if @flash_array.present?
        page.replace_html("main_div", :partial => "ui_4") # Replace the main div area contents
        page << javascript_reload_toolbars
      end
    end
  end

  def edit
    set_form_vars # Go fetch the settings into the object for the form
    session[:changed] = @changed = false
    build_tabs
  end

  # New tab was pressed
  def change_tab
    assert_privileges('my_settings_admin')
    @tabform = "ui_" + params['uib-tab'] if params['uib-tab'] != "5"
    edit
    render :action => "show"
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def filters_field_changed
    assert_privileges('my_settings_default_filters')
    return unless load_edit("config_edit__ui3", "configuration")

    id = params[:id].split('-').last.to_i
    @edit[:new].find { |x| x[:id] == id }[:search_key] = params[:check] == '1' ? nil : '_hidden_'
    @edit[:current].each_with_index do |arr, i| # needed to compare each array element's attributes to find out if something has changed
      next if @edit[:new][i][:search_key] == arr[:search_key]

      @changed = true
      break
    end
    @changed ||= false
    render :update do |page|
      page << javascript_prologue
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  # AJAX driven routine for gtl view selection
  def view_selected
    assert_privileges('my_settings_default_views')
    # ui1 form
    return unless load_edit("config_edit__ui1", "configuration")

    @edit[:new][:views][VIEW_RESOURCES[params[:resource]]] = params[:view] # Capture the new view setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page << javascript_for_miq_button_visibility(@changed)
      page.replace('tab_div', :partial => "ui_1")
    end
  end

  # AJAX driven routine for theme selection
  def theme_changed
    assert_privileges('my_settings_visuals')
    # ui1 theme changed
    @edit = session[:edit]
    @edit[:new][:display][:theme] = params[:theme] # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page.replace('tab_div', :partial => 'ui_1')
    end
  end

  def update
    assert_privileges('my_settings_admin')
    if params["save"]
      get_form_vars if @tabform != "ui_3"
      case @tabform
      when "ui_3" # User Filters tab
        @edit = session[:edit]
        @edit[:new].each do |filter|
          search = MiqSearch.find(filter[:id])
          search.update(:search_key => filter[:search_key]) unless search.search_key == filter[:search_key]
        end
        add_flash(_("Default Filters saved successfully"))
        edit
        render :action => "show"
        return # No config file for Visuals yet, just return
      end
    elsif params["reset"]
      edit
      add_flash(_("All changes have been reset"), :warning)
      render :action => "show"
    end
  end

  # Show the users list
  def show_timeprofiles
    build_tabs if params[:action] == "change_tab" || %w[cancel add save].include?(params[:button])
    @timeprofiles = if report_admin_user?
                      TimeProfile.in_my_region.ordered_by_desc
                    else
                      TimeProfile.in_my_region.for_user(session[:userid]).ordered_by_desc
                    end
    timeprofile_set_days_hours
    @initial_table_data = table_data
    drop_breadcrumb(:name => _("Time Profiles"), :url => "/configuration/change_tab/?tab=4")
  end

  def timeprofile_set_days_hours(_timeprofile = @timeprofile)
    @timeprofile_details = {}
    @timeprofiles.each do |timeprofile|
      @timeprofile_details[timeprofile.description] = {}
      profile_key = timeprofile.profile[:days].nil? ? "days" : :days
      @timeprofile_details[timeprofile.description][:days] =
        timeprofile.profile[profile_key].collect { |day| DateTime::ABBR_DAYNAMES[day.to_i] }
      profile_key = timeprofile.profile[:hours].nil? ? "hours" : :hours
      @timeprofile_details[timeprofile.description][:hours] = []
      temp_arr = timeprofile.profile[profile_key].collect(&:to_i).sort
      st = ""
      temp_arr.each_with_index do |hr, i|
        if hr.to_i + 1 == temp_arr[i + 1]
          st = "#{get_hr_str(hr).split('-').first}-" if st == ""
        else
          hours = st == '' ? get_hr_str(hr) : st + get_hr_str(hr).split('-').last
          @timeprofile_details[timeprofile.description][:hours].push(hours)
          st = ""
        end
      end
      if @timeprofile_details[timeprofile.description][:hours].length > 1 &&
         @timeprofile_details[timeprofile.description][:hours].first.split('-').first == "12AM" &&
         @timeprofile_details[timeprofile.description][:hours].last.split('-').last == "12AM"
        # manipulating midnight hours to be displayed on show screen
        @timeprofile_details[timeprofile.description][:hours][0] =
          @timeprofile_details[timeprofile.description][:hours].last.split('-').first + '-' +
          @timeprofile_details[timeprofile.description][:hours].first.split('-').last
        @timeprofile_details[timeprofile.description][:hours].delete_at(@timeprofile_details[timeprofile.description][:hours].length - 1)
      end
      @timeprofile_details[timeprofile.description][:tz] = if timeprofile.profile[:tz].nil?
                                                             timeprofile.profile["tz"]
                                                           else
                                                             timeprofile.profile[:tz]
                                                           end
    end
  end

  def get_hr_str(hr)
    hours = (1..12).to_a
    hour = hr.to_i
    case hour
    when 0..10  then from = to = "AM"
    when 11     then from, to = %w[AM PM]
    when 12..22 then from = to = "PM"
    else             from, to = %w[PM AM]
    end
    hour = hour >= 12 ? hour - 12 : hour
    "#{hours[hour - 1]}#{from}-#{hours[hour]}#{to}"
  end

  def timeprofile_new
    assert_privileges("timeprofile_new")
    @all_timezones = ActiveSupport::TimeZone.all.collect { |tz| ["(GMT#{tz.formatted_offset}) #{tz.name}", tz.name] }.freeze
    @timeprofile = TimeProfile.new
    @timeprofile_action = "timeprofile_new"
    @userid = session[:userid]
    @in_a_form = true
    @breadcrumbs = []
    drop_breadcrumb(:name => _("Add new Time Profile"), :url => "/configuration/timeprofile_edit")
    render :action => "timeprofile_edit"
  end

  def timeprofile_edit
    assert_privileges("tp_edit")
    @all_timezones = ActiveSupport::TimeZone.all.collect { |tz| ["(GMT#{tz.formatted_offset}) #{tz.name}", tz.name] }.freeze
    @timeprofile = TimeProfile.find(params[:id])
    @timeprofile_action = "timeprofile_edit"
    @initial_reports_table_data = reports_table_data

    if @timeprofile.profile_type == "global" && !report_admin_user?
      @tp_restricted = true
      title = _("Time Profile")
    else
      title = _("Edit")
    end

    add_flash(_("Global Time Profile cannot be edited")) if @timeprofile.profile_type == "global" && !report_admin_user?
    session[:changed] = false
    @userid = session[:userid]
    @in_a_form = true
    drop_breadcrumb(:name => _("%{title} '%{description}'") % {:title       => title,
                                                               :description => @timeprofile.description},
                    :url  => "/configuration/timeprofile_edit")
  end

  # Delete all selected or single displayed VM(s)
  def timeprofile_delete
    assert_privileges("tp_delete")
    timeprofiles = []
    unless params[:id] # showing a list, scan all selected timeprofiles
      timeprofiles = find_checked_items
      if timeprofiles.empty?
        add_flash(_("No Time Profiles were selected for deletion"), :error)
      else
        selected_timeprofiles = TimeProfile.where(:id => timeprofiles)
        selected_timeprofiles.each do |tp|
          if tp.description == "UTC"
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("Default Time Profile \"%{name}\" cannot be deleted") % {:name => tp.description}, :error)
          elsif tp.profile_type == "global" && !report_admin_user?
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("\"%{name}\": Global Time Profiles cannot be deleted") % {:name => tp.description}, :error)
          elsif !tp.miq_reports.empty?
            timeprofiles.delete(tp.id.to_s)
            add_flash(n_("\"%{name}\": In use by %{rep_count} Report, cannot be deleted",
                         "\"%{name}\": In use by %{rep_count} Reports, cannot be deleted",
                         tp.miq_reports.count) % {:name => tp.description, :rep_count => tp.miq_reports.count}, :error)
          end
        end
      end
      process_timeprofiles(timeprofiles, "destroy") unless timeprofiles.empty?
    end
    set_form_vars
  end

  def timeprofile_copy
    assert_privileges("tp_copy")
    session[:set_copy] = "copy"
    @all_timezones = ActiveSupport::TimeZone.all.collect { |tz| ["(GMT#{tz.formatted_offset}) #{tz.name}", tz.name] }.freeze
    @in_a_form = true
    @timeprofile = TimeProfile.find(params[:id])
    @timeprofile_action = "timeprofile_copy"
    session[:changed] = false
    @userid = session[:userid]
    drop_breadcrumb(:name => _("Adding copy of '%{description}'") % {:description => @timeprofile.description},
                    :url  => "/configuration/timeprofile_edit")
    render :action => "timeprofile_edit"
  end

  def show
    show_timeprofiles if params[:typ] == "timeprofiles"
  end

  def time_profile_form_fields
    assert_privileges("tp_edit")
    @timeprofile = TimeProfile.new if params[:id] == 'new'
    @timeprofile = TimeProfile.find(params[:id]) if params[:id] != 'new'

    render :json => {
      :description             => @timeprofile.description,
      :admin_user              => report_admin_user?,
      :restricted_time_profile => @timeprofile.profile_type == "global" && !report_admin_user?,
      :profile_type            => @timeprofile.profile_type || "user",
      :profile_tz              => @timeprofile.tz.nil? ? "" : @timeprofile.tz,
      :rollup_daily            => !@timeprofile.rollup_daily_metrics.nil?,
      :all_days                => Array(@timeprofile.days).size == 7,
      :days                    => Array(@timeprofile.days).uniq.sort,
      :all_hours               => Array(@timeprofile.hours).size == 24,
      :hours                   => Array(@timeprofile.hours).uniq.sort,
      :miq_reports_count       => @timeprofile.miq_reports.count
    }
  end

  def self.session_key_prefix
    "configuration"
  end

  private

  def table_data
    rows = []
    @timeprofiles.each do |timeprofile|
      cells = []
      row = {}
      row[:clickId] = timeprofile.id.to_s
      row[:clickable] = true
      row[:id] = timeprofile.id.to_s
      cells.push({:is_checkbox => true})
      cells.push({:text => timeprofile.description})
      cells.push({:text => timeprofile.profile_type})
      cells.push({:text => timeprofile.profile_key})
      cells.push({:text => @timeprofile_details[timeprofile.description][:days].join(", ")})
      cells.push({:text => @timeprofile_details[timeprofile.description][:hours].join(", ")})
      cells.push({:text => @timeprofile_details[timeprofile.description][:tz]})
      cells.push({:text => timeprofile.rollup_daily_metrics.to_s.capitalize})
      row[:cells] = cells
      rows.push(row)
    end
    rows
  end

  def reports_table_data
    rows = []
    @timeprofile.miq_reports.sort_by { |a| a.name.downcase }.each do |report|
      cells = []
      row = {}
      row[:clickable] = false
      row[:id] = report.id.to_s
      cells.push({:text => report.name, :icon => 'fa fa-file-text-o'})
      cells.push({:text => report.title})
      row[:cells] = cells
      rows.push(row)
    end
    rows
  end

  # copy single selected Object
  def edit_record
    obj = find_checked_items
    @refresh_partial = "timeprofile_edit"
    @redirect_id = obj[0]
  end

  # copy single selected Object
  def copy_record
    obj = find_checked_items
    @refresh_partial = "timeprofile_copy"
    @redirect_id = obj[0]
  end

  def build_tabs
    @breadcrumbs = []
    if @tabform != "ui_4"
      drop_breadcrumb({:name => _("User Interface Configuration"), :url => "/configuration/edit"}, true)
    end

    @active_tab = @tabform.split("_").last

    @tabs = []
    @tabs.push(["1", _("Visual")])          if role_allows?(:feature => "my_settings_visuals")
    @tabs.push(["3", _("Default Filters")]) if role_allows?(:feature => "my_settings_default_filters")
    @tabs.push(["4", _("Time Profiles")])   if role_allows?(:feature => "my_settings_time_profiles")
  end

  def merge_in_user_settings(settings)
    if (user_settings = current_user.try(:settings))
      settings.each do |key, value|
        value.merge!(user_settings[key]) unless user_settings[key].nil?
      end
    end
    settings
  end

  # * start with DEFAULT_SETTINGS
  # * merge in current session changes
  # * merge in any settings from the DB if they exist
  def init_settings
    merge_in_user_settings(copy_hash(DEFAULT_SETTINGS))
  end

  def set_form_vars
    case @tabform
    when 'ui_1'
      @edit = {
        :current => init_settings,
        :key     => 'config_edit__ui1',
      }

      current_tz = @edit.fetch_path(:current, :display, :timezone)
      if current_tz.blank?
        @edit.store_path(:current, :display, :timezone, ::Settings.server.timezone)
      end
    when 'ui_3'
      filters = MiqSearch.where(:search_type => "default")
      current = filters.map do |filter|
        {:id => filter.id, :search_key => filter.search_key}
      end
      @edit = {
        :key         => 'config_edit__ui3',
        :set_filters => true,
        :current     => current,
      }
      @df_tree = TreeBuilderDefaultFilters.new(:df_tree, @sb, true, :data => filters)
      self.x_active_tree = :df_tree
    when 'ui_4'
      @edit = {
        :current => {},
        :key     => 'config_edit__ui4',
      }
      @edit[:timeprofile_id] = @timeprofile.try(:id)
      if %w[timeprofile_new timeprofile_copy timeprofile_edit timeprofile_update].include?(params[:action])
        @edit[:current] = {
          :description  => @timeprofile.description,
          :profile_type => @timeprofile.profile_type || "user",
          :profile_key  => @timeprofile.profile_key,
          :profile      => {
            :days  => Array(@timeprofile.days).uniq.sort,
            :hours => Array(@timeprofile.hours).uniq.sort,
            :tz    => @timeprofile.tz,
          },
          :rollup_daily => @timeprofile.rollup_daily_metrics,
        }
        @edit[:all_days]  = @edit.fetch_path(:current, :profile, :days).length == 7
        @edit[:all_hours] = @edit.fetch_path(:current, :profile, :hours).length == 24
      end
      show_timeprofiles
    end
    @edit[:new] = copy_hash(@edit[:current])
    session[:edit] = @edit
  end

  def get_form_vars
    @edit = session[:edit]
    case @tabform
    when "ui_1" # Visual Settings tab
      @edit[:new][:perpage][:grid] = params[:perpage_grid].to_i if params[:perpage_grid]
      @edit[:new][:perpage][:tile] = params[:perpage_tile].to_i if params[:perpage_tile]
      @edit[:new][:perpage][:list] = params[:perpage_list].to_i if params[:perpage_list]
      @edit[:new][:perpage][:reports] = params[:perpage_reports].to_i if params[:perpage_reports]
      @edit[:new][:display][:theme] = params[:display_theme] unless params[:display_theme].nil?
      @edit[:new][:display][:bg_color] = params[:bg_color] unless params[:bg_color].nil?
      @edit[:new][:display][:reporttheme] = params[:display_reporttheme] unless params[:display_reporttheme].nil?
      @edit[:new][:display][:dashboards] = params[:display_dashboards] unless params[:display_dashboards].nil?
      @edit[:new][:display][:timezone] = params[:display_timezone] unless params[:display_timezone].nil?
      @edit[:new][:display][:startpage] = params[:start_page] unless params[:start_page].nil?
      @edit[:new][:display][:locale] = params[:display_locale] if params[:display_locale]
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
    when "ui_3" # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
    when "ui_4" # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
    end
  end

  def get_session_data
    super
    @tabform      = session[:config_tabform]    if session[:config_tabform]
    @schema_ver   = session[:config_schema_ver] if session[:config_schema_ver]
    @zone_options = session[:zone_options]      if session[:zone_options]
  end

  def set_session_data
    super
    session[:config_tabform]    = @tabform
    session[:config_schema_ver] = @schema_ver
    session[:vm_filters]        = @filters
    session[:vm_catinfo]        = @catinfo
    session[:zone_options]      = @zone_options
  end

  def merge_settings(user_settings, global_settings)
    prune_old_settings(user_settings ? user_settings.merge(global_settings) : global_settings)
  end

  # typically passing in session, but sometimes passing in @session
  def prune_old_settings(s)
    # ui_1
    s[:display].delete(:pres_mode)          # :pres_mode replaced by :theme
    s.delete(:css)                          # Moved this to @css
    s.delete(:adv_search)                   # These got in around sprint 40 by accident
    s[:display].delete(:vmcompare)          # :vmcompare moved to :views hash
    s[:display].delete(:vm_summary_cool)    # :vm_summary_cool moved to :views hash
    s[:views].delete(:vm_summary_cool)      # :views/:vm_summary_cool changed to :dashboards
    s[:views].delete(:dashboards)           # :dashboards is obsolete now

    s
  end

  def breadcrumbs_options
    {
      :breadcrumbs => [
        {:title => _("My Settings")},
      ],
    }
  end

  menu_section :set
end
