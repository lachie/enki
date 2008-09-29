class Comment < ActiveRecord::Base
  DEFAULT_LIMIT = 15

  class << self  
    def protected_attribute?(attribute)
      [:author, :body].include?(attribute.to_sym)
    end
  end

  attr_accessor :openid_error
  attr_accessor :openid_valid

  belongs_to :post

  before_save   :check_spamminess, :apply_filter

  after_save    :denormalize
  after_destroy :denormalize

  validates_presence_of :author
  validates_presence_of :body

  validates_presence_of :post

  # validate :open_id_thing
  def validate
    super 
    errors.add(:base, openid_error) unless openid_error.blank?
  end
  
  def viking_attributes
    {
      :article_date         => post.created_at,
      :permalink            => post.slug,
      
      :user_ip              => author_ip,
      :comment_author       => author,
      :comment_type         => 'comment',
      :comment_content      => body,
      :comment_author_email => author_email
    }
  end

  require 'pp'
  
  def check_spamminess
    pp viking_attributes
    viking_says = Viking.check_comment(viking_attributes)
    puts "viking_says:"
    pp viking_says
    self.approved = !viking_says[:spam]
  end
  
  def apply_filter
    self.body_html = Lesstile.format_as_xhtml(
      self.body,
      :code_formatter => Lesstile::CodeRayFormatter
    )
  end
  
  def blank_openid_fields
    self.author_openid_authority = ""
    self.author_url = ""
    self.author_email = ""
  end

  def requires_openid_authentication?
    !!self.author.index(".")
  end

  def trusted_user?
    false
  end

  def user_logged_in?
    false
  end

  def denormalize
    self.post.denormalize_comments_count!
  end

  def destroy_with_undo
    undo_item = nil
    transaction do
      self.destroy
      undo_item = DeleteCommentUndo.create_undo(self)
    end
    undo_item
  end

  # Delegates
  def post_title
    post.title
  end
  
  DEFAULT_FIND_RECENT = { 
    :limit => DEFAULT_LIMIT,
    :order => 'created_at DESC'
  }
  
  named_scope :find_recent do |*args|
    args = args.empty? ? {} : args.shift
    DEFAULT_FIND_RECENT.merge(args)
  end

  class << self
    def build_for_preview(params)
      comment = Comment.new(params)
      comment.created_at = Time.now
      comment.apply_filter

      if comment.requires_openid_authentication?
        comment.author_url = comment.author
        comment.author = "Your OpenID Name"
      end
      comment
    end
  end
  
end
