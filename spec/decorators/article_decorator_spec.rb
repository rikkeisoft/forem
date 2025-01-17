require "rails_helper"

RSpec.describe ArticleDecorator, type: :decorator do
  def create_article(*args)
    article = create(:article, *args)
    article.decorate
  end

  let(:article) { build(:article) }
  let(:published_article) { create_article(published: true) }
  let(:organization) { build(:organization) }

  context "with serialization" do
    it "serializes both the decorated object IDs and decorated methods" do
      article = published_article
      expected_result = { "id" => article.id, "published_at_int" => article.published_at_int }
      expect(article.as_json(only: [:id], methods: [:published_at_int])).to eq(expected_result)
    end

    it "serializes collections of decorated objects" do
      article = published_article
      decorated_collection = Article.published.decorate
      expected_result = [{ "id" => article.id, "published_at_int" => article.published_at_int }]
      expect(decorated_collection.as_json(only: [:id], methods: [:published_at_int])).to eq(expected_result)
    end
  end

  describe "#current_state_path" do
    it "returns the path /:username/:slug when published" do
      article = published_article
      expect(article.current_state_path).to eq("/#{article.username}/#{article.slug}")
    end

    it "returns the path /:username/:slug?:password when draft" do
      article = create_article(published: false)
      expected_result = "/#{article.username}/#{article.slug}?preview=#{article.password}"
      expect(article.current_state_path).to eq(expected_result)
    end
  end

  describe "#processed_canonical_url" do
    it "strips canonical_url" do
      article.canonical_url = " http://google.com "
      expect(article.decorate.processed_canonical_url).to eq("http://google.com")
    end

    it "returns the article url without a canonical_url" do
      article.canonical_url = ""
      expected_url = "https://#{ApplicationConfig['APP_DOMAIN']}#{article.path}"
      expect(article.decorate.processed_canonical_url).to eq(expected_url)
    end
  end

  describe "#comments_to_show_count" do
    it "returns 25 if does not have a discuss tag" do
      article.cached_tag_list = ""
      expect(article.decorate.comments_to_show_count).to eq(25)
    end

    it "returns 75 if it does have a discuss tag" do
      article.cached_tag_list = "discuss, python"
      expect(article.decorate.comments_to_show_count).to eq(75)
    end
  end

  describe "#cached_tag_list_array" do
    it "returns no tags if the cached tag list is empty" do
      article.cached_tag_list = ""
      expect(article.decorate.cached_tag_list_array).to be_empty
    end

    it "returns cached tag list as an array" do
      article.cached_tag_list = "discuss, python"
      expect(article.decorate.cached_tag_list_array).to eq(%w[discuss python])
    end
  end

  describe "#url" do
    it "returns the article url" do
      expected_url = "https://#{ApplicationConfig['APP_DOMAIN']}#{article.path}"
      expect(article.decorate.url).to eq(expected_url)
    end
  end

  describe "#title_length_classification" do
    it "returns article title length classifications" do
      article.title = "0" * 106
      expect(article.decorate.title_length_classification).to eq("longest")
      article.title = "0" * 81
      expect(article.decorate.title_length_classification).to eq("longer")
      article.title = "0" * 61
      expect(article.decorate.title_length_classification).to eq("long")
      article.title = "0" * 23
      expect(article.decorate.title_length_classification).to eq("medium")
      article.title = "0" * 20
      expect(article.decorate.title_length_classification).to eq("short")
    end
  end

  describe "internal_utm_params" do
    it "returns utm params for a boosted article" do
      article.boosted_additional_articles = true

      params = ["utm_medium=internal", "utm_campaign=_boosted", "booster_org="]
      expected_result = "?utm_source=additional_box&#{params.join('&')}"
      expect(article.decorate.internal_utm_params).to eq(expected_result)
    end

    it "returns utm params for a boosted article belonging to an organization" do
      article.boosted_additional_articles = true
      article.organization = organization

      slug = organization.slug
      params = ["utm_medium=internal", "utm_campaign=#{slug}_boosted", "booster_org=#{slug}"]
      expected_result = "?utm_source=additional_box&#{params.join('&')}"
      expect(article.decorate.internal_utm_params).to eq(expected_result)
    end

    it "returns utm params for a regular article" do
      article.boosted_additional_articles = false

      params = ["utm_medium=internal", "utm_campaign=regular", "booster_org="]
      expected_result = "?utm_source=additional_box&#{params.join('&')}"
      expect(article.decorate.internal_utm_params).to eq(expected_result)
    end

    it "returns utm params for a regular article belonging to an organization" do
      article.boosted_additional_articles = false
      article.organization = organization

      slug = organization.slug
      params = ["utm_medium=internal", "utm_campaign=regular", "booster_org=#{slug}"]
      expected_result = "?utm_source=additional_box&#{params.join('&')}"
      expect(article.decorate.internal_utm_params).to eq(expected_result)
    end

    it "returns utm params for an article in a different place" do
      article.boosted_additional_articles = false

      params = ["utm_medium=internal", "utm_campaign=regular", "booster_org="]
      expected_result = "?utm_source=homepage&#{params.join('&')}"
      expect(article.decorate.internal_utm_params("homepage")).to eq(expected_result)
    end
  end

  describe "#published_at_int" do
    it "returns the publication date as an integer" do
      expect(article.decorate.published_at_int).to eq(article.published_at.to_i)
    end
  end

  describe "#description_and_tags" do
    it "creates proper description when it is not present and body is present and short, and tags are present" do
      body_markdown = "---\ntitle: Title\npublished: false\ndescription:\ntags: heytag\n---\n\nHey this is the article"
      expected_result = "Hey this is the article. Tagged with heytag."
      expect(create_article(body_markdown: body_markdown).description_and_tags).to eq(expected_result)
    end

    it "creates proper description when it is not present and body is present and short, and tags are not present" do
      body_markdown = "---\ntitle: Title\npublished: false\ndescription:\ntags:\n---\n\nHey this is the article"
      expect(create_article(body_markdown: body_markdown).description_and_tags).to eq("Hey this is the article.")
    end

    it "creates proper description when it is not present and body is present and long, and tags are present" do
      paragraphs = Faker::Hipster.paragraph(sentence_count: 40)
      body_markdown = "---\ntitle: Title\npublished: false\ndescription:\ntags: heytag\n---\n\n#{paragraphs}"
      expect(create_article(body_markdown: body_markdown).description_and_tags).to end_with("... Tagged with heytag.")
    end

    it "creates proper description when it is not present and body is not present and long, and tags are present" do
      body_markdown = "---\ntitle: Title\npublished: false\ndescription:\ntags: heytag\n---\n\n"
      created_article = create_article(body_markdown: body_markdown)
      parsed_post_by_string = "A post by #{created_article.user.name}"
      parsed_post_by_string += "." unless created_article.user.name.end_with?(".")
      expect(created_article.description_and_tags).to eq("#{parsed_post_by_string} Tagged with heytag.")
    end

    it "returns search_optimized_description_replacement if it is present" do
      body_markdown = "---\ntitle: Title\npublished: false\ndescription:\ntags: heytag\n---\n\nHey this is the article"
      search_optimized_description_replacement = "Hey this is the expected result"
      expect(create_article(body_markdown: body_markdown,
                            search_optimized_description_replacement: search_optimized_description_replacement)
        .description_and_tags).to eq(search_optimized_description_replacement)
    end
  end

  describe "#video_metadata" do
    it "responds with a hash representation of video metadata" do
      article_with_video = create(:article,
                                  video_code: "ABC",
                                  video_source_url: "https://cdn.com/ABC.m3u8",
                                  video_thumbnail_url: "https://cdn.com/ABC.png",
                                  video_closed_caption_track_url: "https://cdn.com/ABC_captions")

      expect(article_with_video.decorate.video_metadata).to eq(
        {
          id: article_with_video.id,
          video_code: article_with_video.video_code,
          video_source_url: article_with_video.video_source_url,
          video_thumbnail_url: article_with_video.cloudinary_video_url,
          video_closed_caption_track_url: article_with_video.video_closed_caption_track_url
        },
      )
    end
  end
end
