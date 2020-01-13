# frozen_string_literal: true

class RemoteLogCopier < LogCopier
  def copy_logs
    zipfile_name_and_path = Rails.root.join('public', 'uploads', reservation.zipfile_name)
    system("unzip #{zipfile_name_and_path} *.log -d #{directory_to_copy_to}")
  end
end
