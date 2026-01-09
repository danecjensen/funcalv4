module User::Avatarable
  extend ActiveSupport::Concern

  included do
    has_one_attached :avatar
  end

  def avatar_url(size: 100)
    if avatar.attached?
      avatar
    else
      gravatar_url(size)
    end
  end

  private

  def gravatar_url(size)
    hash = Digest::MD5.hexdigest(email.downcase)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=identicon"
  end
end
