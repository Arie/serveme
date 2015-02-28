class MakeColumnsMb4Compatible < ActiveRecord::Migration
  def up
    # execute "alter table groups modify name varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    # execute "alter table users modify email varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    # execute "alter table users modify reset_password_token varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    # execute "alter table users modify name varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    # execute "alter table users modify nickname varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    # execute "alter table users modify logs_tf_api_key varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
  end

  def down
    # execute "alter table groups modify name varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    # execute "alter table users modify email varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    # execute "alter table users modify reset_password_token varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    # execute "alter table users modify name varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    # execute "alter table users modify nickname varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    # execute "alter table users modify logs_tf_api_key varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
  end
end
