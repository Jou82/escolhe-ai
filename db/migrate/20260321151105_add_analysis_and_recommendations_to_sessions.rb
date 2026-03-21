class AddAnalysisAndRecommendationsToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :analysis, :text
    add_column :sessions, :recommendations_data, :text
  end
end
