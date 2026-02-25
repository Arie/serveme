class AddCloudPhaseTimestamps < ActiveRecord::Migration[7.2]
  def change
    add_column :servers, :cloud_vm_running_at, :datetime
    add_column :servers, :cloud_vm_progress, :integer
    add_column :servers, :cloud_ssh_ready_at, :datetime
    add_column :reservations, :ready_at, :datetime
  end
end
