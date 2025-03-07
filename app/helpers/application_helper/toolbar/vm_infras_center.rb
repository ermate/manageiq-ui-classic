class ApplicationHelper::Toolbar::VmInfrasCenter < ApplicationHelper::Toolbar::Basic
  button_group('vm_vmdb', [
    select(
      :vm_vmdb_choice,
      nil,
      N_('Configuration'),
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :vm_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected items'),
          N_('Refresh Relationships and Power States'),
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Refresh relationships and power states for all items related to the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on the selected items'),
          N_('Perform SmartState Analysis'),
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Perform SmartState Analysis on the selected items?"),
          :enabled      => false,
          :onwhen       => "1+",
          :klass        => ApplicationHelper::Button::BasicImage),
        button(
          :vm_collect_running_processes,
          'fa fa-eyedropper fa-lg',
          N_('Extract Running Processes for the selected items'),
          N_('Extract Running Processes'),
          :confirm      => N_("Extract Running Processes for the selected items?"),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_compare,
          'ff ff-compare-same fa-lg',
          N_('Select two or more items to compare'),
          N_('Compare Selected items'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "2+"),
        separator,
        button(
          :vm_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single item to edit'),
          N_('Edit Selected item'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1"),
        button(
          :vm_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for the selected items'),
          N_('Set Ownership'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected items from Inventory'),
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Warning: The selected items and ALL of their components will be permanently removed!"),
          :enabled      => false,
          :onwhen       => "1+"),
        separator,
        button(
          :vm_right_size,
          'ff ff-database-squeezed fa-lg',
          N_('CPU/Memory Recommendations of selected item'),
          N_('Right-Size Recommendations'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1"),
        button(
          :vm_reconfigure,
          'pficon pficon-edit fa-lg',
          N_('Reconfigure the Memory/CPUs of selected items'),
          N_('Reconfigure Selected items'),
          :klass        => ApplicationHelper::Button::VmReconfigureMultiple,
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
      ]
    ),
  ])
  button_group('vm_policy', [
    select(
      :vm_policy_choice,
      nil,
      N_('Policy'),
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :vm_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected items'),
          N_('Manage Policies'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for the selected items'),
          N_('Policy Simulation'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for the selected items'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled      => true,
          :onwhen       => "1+",
          :klass        => ApplicationHelper::Button::VmCheckCompliance),
      ]
    ),
  ])
  button_group('vm_lifecycle', [
    select(
      :vm_lifecycle_choice,
      nil,
      N_('Lifecycle'),
      :items => [
        button(
          :vm_miq_request_new,
          'pficon pficon-add-circle-o fa-lg',
          N_('Request to Provision VMs'),
          N_('Provision VMs'),
          :url_parms    => "main_div",
          :send_checked => true,
          :klass        => ApplicationHelper::Button::VmMiqRequestNew),
        button(
          :vm_clone,
          'ff ff-clone fa-lg',
          N_('Clone this item'),
          N_('Clone selected item'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1",
          :klass        => ApplicationHelper::Button::BasicImage),
        button(
          :vm_publish,
          'pficon pficon-export fa-lg',
          N_('Publish selected VM to a Template'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1",
          :klass        => ApplicationHelper::Button::BasicImage),
        button(
          :vm_migrate,
          'pficon pficon-migration fa-lg',
          N_('Migrate selected items to another Host/Datastore'),
          N_('Migrate selected items'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+",
          :klass        => ApplicationHelper::Button::BasicImage),
        button(
          :vm_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for the selected items'),
          N_('Set Retirement Dates'),
          :url_parms    => "main_div",
          :send_checked => true,
          :enabled      => false,
          :onwhen       => "1+",
          :klass        => ApplicationHelper::Button::BasicImage),
        button(
          :vm_retire_now,
          'fa fa-clock-o fa-lg',
          N_('Retire the selected items'),
          N_('Retire selected items'),
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Retire the selected items?"),
          :enabled      => false,
          :onwhen       => "1+",
          :klass        => ApplicationHelper::Button::BasicImage),
      ]
    ),
  ])
  button_group('vm_operations', [
    select(
      :vm_power_choice,
      nil,
      N_('Power Operations'),
      N_('Power'),
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :vm_guest_shutdown,
          nil,
          N_('Shutdown the Guest OS on the selected items'),
          N_('Shutdown Guest'),
          :icon         => "fa fa-stop fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Shutdown the Guest OS on the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_guest_restart,
          nil,
          N_('Restart the Guest OS on the selected items'),
          N_('Restart Guest'),
          :icon         => "pficon pficon-restart fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Restart the Guest OS on the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        separator,
        button(
          :vm_start,
          nil,
          N_('Power On the selected items'),
          N_('Power On'),
          :icon         => "pficon pficon-on fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Power On the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_stop,
          nil,
          N_('Power Off the selected items'),
          N_('Power Off'),
          :icon         => "pficon pficon-off fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Power Off the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_suspend,
          nil,
          N_('Suspend the selected items'),
          N_('Suspend'),
          :icon         => "pficon pficon-paused fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Suspend the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
        button(
          :vm_reset,
          nil,
          N_('Reset the selected items'),
          N_('Reset'),
          :icon         => "fa fa-refresh fa-lg",
          :url_parms    => "main_div",
          :send_checked => true,
          :confirm      => N_("Reset the selected items?"),
          :enabled      => false,
          :onwhen       => "1+"),
      ]
    ),
  ])
end
