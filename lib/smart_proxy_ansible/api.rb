# frozen_string_literal: true

module Proxy
  module Ansible
    # API endpoints. Most of the code should be calling other classes,
    # please keep the actual implementation of the endpoints outside
    # of this class.
    class Api < Sinatra::Base
      include ::Proxy::Log

      get '/roles' do
        RolesReader.list_roles.to_json
      end

      get '/roles/variables' do
        variables = {}
        RolesReader.list_roles.each do |role_name|
          variables.merge!(extract_variables(role_name))
        rescue ReadVariablesException => e
          # skip what cannot be parsed
          logger.error e
        end
        variables.to_json
      end

      get '/roles/:role_name/variables' do |role_name|
        extract_variables(role_name).to_json
      rescue ReadVariablesException => e
        logger.error e
        {}.to_json
      end

      get '/playbooks_names' do
        PlaybooksReader.playbooks_names.to_json
      end

      get '/playbooks/:playbooks_names?' do
        PlaybooksReader.playbooks(params[:playbooks_names]).to_json
      end

      get '/vcs_clone/repo_information' do
        repo_info = VCSCloner.repo_information(params)
        status repo_info.status
        body repo_info.payload.to_json
      end

      get '/vcs_clone/roles' do
        get_installed = VCSCloner.list_installed_roles
        status get_installed.status
        body get_installed.payload.to_json
      end

      post '/vcs_clone/roles' do
        install = VCSCloner.install(params['repo_info'])
        status install.status
        body install.payload.to_json
      end

      put '/vcs_clone/roles/:role_name' do
        update = VCSCloner.update(params['repo_info'])
        status update.status
        body update.payload.to_json
      end

      delete '/vcs_clone/roles/:role_name' do
        delete = VCSCloner.delete(params)
        status delete.status
        body delete.payload.to_json
      end

      private

      def extract_variables(role_name)
        variables = {}
        role_name_parts = role_name.split('.')
        if role_name_parts.count == 3
          ReaderHelper.collections_paths.split(':').each do |path|
            variables[role_name] = VariablesExtractor
                                   .extract_variables("#{path}/ansible_collections/#{role_name_parts[0]}/#{role_name_parts[1]}/roles/#{role_name_parts[2]}") if variables[role_name].nil? || variables[role_name].empty?
          end
        else
          RolesReader.roles_path.split(':').each do |path|
            role_path = "#{path}/#{role_name}"
            if File.directory?(role_path)
              variables[role_name] ||= VariablesExtractor.extract_variables(role_path)
            end
          end
        end
        variables
      end
    end
  end
end
