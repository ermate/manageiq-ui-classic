module OpsController::Settings::RHN
  extend ActiveSupport::Concern

  # Most of this would better live in a FormClass or similar.
  # Let's move it there once we have the app/presenters in the production branch.

  ###########################################################################
  #
  # Helper and utility methods
  #

  SUBSCRIPTION_TYPES =
    [['Red Hat Subscription Management', 'sm_hosted'],
     ['Red Hat Satellite 6',             'rhn_satellite6']].freeze

  def rhn_subscription_types
    SUBSCRIPTION_TYPES
  end

  def rhn_subscription_map
    @rhn_subscription_map ||= Hash[rhn_subscription_types.map(&:reverse)]
  end

  included do
    private(:rhn_subscription_map)
    private(:rhn_update_information)
    private(:rhn_subscription)
    private(:rhn_save_subscription)
    private(:rhn_credentials_from_edit)
    private(:rhn_fire_available_organizations)
    private(:rhn_load_session)
    private(:rhn_gather_checks)

    helper_method(:rhn_subscription_types)
    private(:rhn_subscription_types)

    helper_method(:rhn_address_string)
    private(:rhn_address_string)

    helper_method(:rhn_account_info_string)
    private(:rhn_account_info_string)

    helper_method(:rhn_default_enabled)
    private(:rhn_default_enabled)
  end

  def rhn_address_string
    product_key = @edit[:new][:register_to]
    product_key = "sm_hosted" unless rhn_subscription_map.key?(product_key)
    rhn_subscription_map[product_key] + _(' Address')
  end

  def rhn_account_info_string
    if @edit[:new][:register_to] == "sm_hosted"
      _("Enter your Red Hat account information")
    else
      _("Enter your Red Hat Network Satellite account information")
    end
  end

  def rhn_default_enabled
    @edit[:new][:register_to] == 'sm_hosted'
  end

  def rhn_update_information
    MiqServer.in_my_region.order(:name).collect do |server|
      status = server.rh_registered ? 'Unsubscribed' : 'Not registered'
      status = 'Subscribed' if server.rh_subscribed

      MiqHashStruct.new(
        :id                => server.id,
        :name              => server.name,
        :status            => status,
        # FIXME: queued for update, up-to-date, ready to update
        #        are not available from the server atm
        # we should create a method .update_status_nice or something like that,
        # in MiqServer or same decorator that would return a nice status string
        :version           => server.version,
        :zone              => server.zone.name,
        :last_check        => server.last_update_check,
        :updates_available => server.updates_available ? 'Yes' : 'No',
        :color             => server.cfme_available_update ? 'red' : 'black',
        :checked           => !!@edit[:new][:servers][server.id],
        :last_message      => server.upgrade_message,
      )
    end
  end

  def rhn_subscription
    db = MiqDatabase.first
    username, = db.auth_user_pwd(:registration)
    MiqHashStruct.new(
      :registered                     => username.present?,
      :registration_type              => db.registration_type,
      :user_name                      => username,
      :server                         => db.registration_server,
      :company_name                   => db.registration_organization_name,
      :subscription                   => rhn_subscription_map[db.registration_type] || 'None',
      :update_repo_name               => db.update_repo_name,
      :version_available              => db.cfme_version_available,
      :registration_http_proxy_server => db.registration_http_proxy_server
    )
  end

  def rhn_save_subscription
    db          = MiqDatabase.first
    credentials = rhn_credentials_from_edit

    db.update_attributes(
      credentials.slice(
        :registration_type,
        :registration_server,
        :registration_http_proxy_server,
        :update_repo_name
      )
    )

    db.update_authentication(
      :registration_http_proxy => {
        :userid   => credentials[:registration_http_proxy_username],
        :password => credentials[:registration_http_proxy_password]
      }
    )

    auth    = {:registration => {:userid => credentials[:userid], :password => credentials[:password]}}
    options = {:required => %i[userid password]}
    db.update_authentication(auth, options)
    unless credentials[:registration_type] == "sm_hosted"
      db.registration_organization = @edit[:new][:customer_org]
      db.registration_organization_display_name = @edit[:organizations].key(@edit[:new][:customer_org])
    end

    begin
      RegistrationSystem.update_rhsm_conf_queue(rhn_credentials_from_edit)
      db.save!
    rescue => bang
      add_flash(_(bang.message), :error)
      @in_a_form = true
      javascript_flash
    else
      add_flash(_("Customer Information successfully saved"))
      @in_a_form = false
      @changed = false
      @edit    = nil
      @sb[:active_tab] = 'settings_rhn'
      settings_get_info('root')
      replace_right_cell(:nodetype => 'root')
    end
  end

  # prepare credentials from @edit into a hash for async call
  def rhn_credentials_from_edit
    {
      :registration_type   => @edit[:new][:register_to],
      :userid              => @edit[:new][:customer_userid],
      :password            => @edit[:new][:customer_password],
      :registration_server => @edit[:new][:server_url],
      :update_repo_name    => @edit[:new][:repo_name],
    }.update(@edit[:new][:use_proxy].to_i == 1 ? {
               :registration_http_proxy_server   => @edit[:new][:proxy_address],
               :registration_http_proxy_username => @edit[:new][:proxy_userid],
               :registration_http_proxy_password => @edit[:new][:proxy_password]
             } : {
               :registration_http_proxy_server   => nil,
               :registration_http_proxy_username => nil,
               :registration_http_proxy_password => nil
             })
  end

  def rhn_fire_available_organizations
    if params[:task_id] # wait_for_task is done --> read the task record
      miq_task = MiqTask.find(params[:task_id])
      if !miq_task.results_ready?
        add_flash(_("Credential validation returned: %{message}") % {:message => miq_task.message}, :error)
      else
        # task succeeded, we have the hash of org names to org keys in miq_task.task_results
        add_flash(_("Credential validation was successful"))
        yield miq_task.task_results
      end
    else # First time --> run the task
      task_id = RegistrationSystem.available_organizations_queue(rhn_credentials_from_edit)
      initiate_wait_for_task(:task_id => task_id)
    end
  end

  def rhn_load_session
    @edit = session[:edit] || {}
    @edit[:new] ||= {}
    @edit[:new][:servers] ||= {}
  end

  # collect checkboxes coming in with a button
  def rhn_gather_checks
    @edit[:new][:servers] = {}

    params.each do |key, value|
      next if key !~ /^check_server_(\d+)$/
      server_id = $1.to_i
      if MiqServer.find(server_id) && (value == '1')
        @edit[:new][:servers][server_id] = true
      else
        @edit[:new][:servers].delete(server_id)
      end
    end
  end

  RHN_OBLIGATORY_FIELD_NAMES = {
    :customer_userid   => _('RHN Login'),
    :customer_password => _('RHN Password'),
    :server_url        => _('Server Address'),
    :repo_name         => _('Repository Name'),
    :proxy_address     => _('HTTP Proxy Address'),
    :customer_org      => _('Organization'),
  }.freeze

  # FIXME: once we have a way to separately allow 'Save' and 'Reset' buttons
  # we can use this method to disable the 'Save' button untill all necessary
  # fields are filled-in.
  def rhn_allow_save?
    obligatory_fields = %i[customer_password customer_userid server_url repo_name]
    obligatory_fields << :customer_org if @edit[:organizations].try(:length).to_i > 1
    obligatory_fields << :proxy_address if @edit[:new][:use_proxy].to_i == 1

    obligatory_fields.find_all do |field|
      if @edit[:new][field].present?
        false
      else
        add_flash(_("%{name} is required") % {:name => RHN_OBLIGATORY_FIELD_NAMES[field]}, :error)
        true
      end
    end.empty?
  end

  ###########################################################################
  #
  # Controller actions
  #
  def rhn_default_server
    params[:server_url] = MiqDatabase.registration_default_values[:registration_server]
    settings_form_field_changed
  end

  def repo_default_name
    settings_form_field_changed
  end

  def rhn_organizations
    rhn_fire_available_organizations do |_organizations|
      render :update do |page|
        page << javascript_prologue
        # TODO: replace following line with this after 5.2: page << set_spinner_off
        page << "miqSparkle(false);"
      end
    end
  end

  def rhn_validate
    assert_privileges('product_update_admin')
    rhn_load_session
    rhn_fire_available_organizations do |organizations|
      if @edit[:new][:register_to] == 'rhn_satellite6'
        # Hash of display names to key names
        @edit[:organizations] = organizations
        if @edit[:organizations].length == 1
          @edit[:new][:customer_org_display], @edit[:new][:customer_org] = @edit[:organizations].first
        else
          @edit[:new][:customer_org] = nil unless @edit[:organizations].key?(@edit[:new][:customer_org_display])
        end
      end
    end

    # rhn_fire_available_organizations is async, if wait_for_task is completed, render the results
    if params[:task_id]
      render :update do |page|
        @changed = (@edit[:new] != @edit[:current])
        page << javascript_prologue
        if @edit[:new][:register_to] == 'rhn_satellite6'
          page.replace_html('settings_rhn', :partial => 'settings_rhn_edit_tab')
          page << javascript_for_miq_button_visibility(@changed) unless flash_errors?
        else
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end

        # TODO: replace following line with this after 5.2: page << set_spinner_off
        page << "miqSparkle(false);"
      end
    end
  end

  # handle buttons in ops/settings/rh updates
  def rhn_buttons
    assert_privileges('product_update_admin')
    @edit = session[:edit]
    rhn_gather_checks
    if params[:button] != 'refresh'
      server_ids = (@edit[:new][:servers].keys rescue [])
      if server_ids.empty?
        add_flash(_("No Server was selected"), :error)
      else
        begin
          case params[:button]
          when 'register'
            MiqServer.queue_update_registration_status(server_ids)
            add_flash(_('Registration has been initiated for the selected Servers'))
          when 'check'
            MiqServer.queue_check_updates(server_ids)
            add_flash(_('Check for updates has been initiated for the selected Servers'))
          when 'update'
            MiqServer.queue_apply_updates(server_ids)
            add_flash(_('Update has been initiated for the selected Servers'))
          end

          javascript_flash
        rescue => error
          add_flash(_("Error occured when queuing action: %{message}") % {:message => error.message}, :error)
          javascript_flash
        end
      end
    else
      settings_get_info('root')
      render :update do |page|
        page << javascript_prologue
        page.replace_html('settings_rhn', :partial => 'settings_rhn_tab')
      end
    end
  end

  def edit_rhn
    assert_privileges('product_update_admin')
    @sb[:active_tab] = 'settings_rhn_edit'
    self.x_active_tree = :settings_tree
    @in_a_form = true

    db = MiqDatabase.first
    @edit ||= {}
    username, password = db.auth_user_pwd(:registration)
    proxy_username, proxy_password = db.auth_user_pwd(:registration_http_proxy)
    @edit[:new] ||= {
      :register_to          => db.registration_type,
      :customer_userid      => username,
      :customer_password    => password,
      :customer_verify      => '',
      :customer_org         => db.registration_organization,
      :customer_org_display => db.registration_organization_display_name,
      :server_url           => db.registration_server,
      :repo_name            => db.update_repo_name,

      :use_proxy            => db.registration_http_proxy_server.to_s.empty? ? 0 : 1,
      :proxy_address        => db.registration_http_proxy_server,
      :proxy_userid         => proxy_username,
      :proxy_password       => proxy_password,
      :proxy_verify         => '',
    }
    @edit[:key] = "#{@sb[:active_tab]}__rhn_edit"
    @edit[:current] = copy_hash(@edit[:new])
    reset_repo_name_from_default
    replace_right_cell(:nodetype => 'rhn')
  end

  private

  def rhn_save_enabled?
    return @changed if @edit[:new][:register_to] != 'rhn_satellite6'
    # @edit[:organizations] gets set when validate button is pressed
    @edit[:new][:register_to] == 'rhn_satellite6' && @edit[:organizations]
  end

  def reset_repo_name_from_default
    MiqDatabase.registration_default_value_for_update_repo_name
  end
end
