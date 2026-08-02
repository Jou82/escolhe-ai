require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.new(email: "test@example.com", password: "password123")
    @user.skip_terms_validation!
    @user.save!
  end

  test "should cascade delete sessions when user is destroyed" do
    session = @user.sessions.create!
    assert_difference("Session.count", -1) do
      @user.destroy
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Session.find(session.id)
    end
  end

  test "should cascade delete likes when user is destroyed" do
    genre = Genre.create!(name: "Action")
    movie = Movie.create!(title: "Test Movie")
    movie.genres << genre
    session = @user.sessions.create!
    like = session.likes.create!(movie: movie)
    assert_difference("Like.count", -1) do
      @user.destroy
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Like.find(like.id)
    end
  end

  test "should not delete movies when user is destroyed" do
    genre = Genre.create!(name: "Drama")
    movie = Movie.create!(title: "Movie Test")
    movie.genres << genre
    original_count = Movie.count
    @user.destroy
    assert_equal original_count, Movie.count
  end

  test "should not delete genres when user is destroyed" do
    genre = Genre.create!(name: "Comedy")
    original_count = Genre.count
    @user.destroy
    assert_equal original_count, Genre.count
  end
end
