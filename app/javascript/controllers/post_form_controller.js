import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "titleInput",
    "bodyInput",
    "linkInput",
    "buildStatusSelect",
    "tagInput",
    "imageInput",
    "videoInput",
    "removeImageInput",
    "removeVideoInput",
    "warningList",
    "warningEmpty",
    "previewTitle",
    "previewBody",
    "previewLink",
    "previewLinkAnchor",
    "previewBuildStatus",
    "previewType",
    "previewTags",
    "previewImageSection",
    "previewImage",
    "previewVideoSection",
    "previewVideo",
    "previewMediaEmpty"
  ]

  static values = {
    postType: String,
    linterMessages: Object,
    typeLabels: Object,
    buildStatusLabels: Object,
    existingImageUrl: String,
    existingImageFilename: String,
    existingVideoUrl: String,
    existingVideoFilename: String
  }

  connect() {
    this.imageObjectUrl = null
    this.videoObjectUrl = null
    this.sync()
  }

  disconnect() {
    this.revokeObjectUrls()
  }

  sync() {
    this.syncTitle()
    this.syncBody()
    this.syncLink()
    this.syncBuildStatus()
    this.syncTags()
    this.syncWarnings()
    this.syncMedia()
  }

  handleImageChange() {
    if (this.hasImageInputTarget && this.imageInputTarget.files.length > 0 && this.hasVideoInputTarget) {
      this.videoInputTarget.value = ""
      if (this.hasRemoveVideoInputTarget) this.removeVideoInputTarget.checked = false
    }

    this.sync()
  }

  handleVideoChange() {
    if (this.hasVideoInputTarget && this.videoInputTarget.files.length > 0 && this.hasImageInputTarget) {
      this.imageInputTarget.value = ""
      if (this.hasRemoveImageInputTarget) this.removeImageInputTarget.checked = false
    }

    this.sync()
  }

  syncTitle() {
    this.previewTitleTarget.textContent = this.titleInputTarget.value.trim() || this.previewTitleTarget.dataset.emptyText
    this.previewTypeTarget.textContent = this.typeLabelsValue[this.postTypeValue]
  }

  syncBody() {
    this.previewBodyTarget.textContent = this.bodyInputTarget.value.trim() || this.previewBodyTarget.dataset.emptyText
  }

  syncLink() {
    if (!this.hasLinkInputTarget) return

    const value = this.linkInputTarget.value.trim()
    const isBlank = value.length === 0

    this.previewLinkAnchorTarget.textContent = isBlank ? "#" : value
    this.previewLinkAnchorTarget.href = isBlank ? "#" : value
    this.previewLinkTarget.classList.toggle("is-hidden", isBlank)
  }

  syncBuildStatus() {
    if (!this.hasBuildStatusSelectTarget) return

    const value = this.buildStatusSelectTarget.value
    this.previewBuildStatusTarget.textContent = this.buildStatusLabelsValue[value] || this.previewBuildStatusTarget.dataset.emptyText
  }

  syncTags() {
    const selectedTags = this.tagInputTargets
      .filter((input) => input.checked)
      .map((input) => input.nextElementSibling.textContent.trim())

    const emptyText = this.previewTagsTarget.dataset.emptyText || ""
    this.previewTagsTarget.innerHTML = ""

    const names = selectedTags.length > 0 ? selectedTags : [ emptyText ]
    names.forEach((name) => {
      const item = document.createElement("li")
      item.textContent = name
      this.previewTagsTarget.appendChild(item)
    })
  }

  syncWarnings() {
    const content = [ this.titleInputTarget.value, this.bodyInputTarget.value ].join("\n")
    const flags = this.detectFlags(content)

    this.warningListTarget.innerHTML = ""
    this.warningEmptyTarget.classList.toggle("is-hidden", flags.length > 0)

    flags.forEach((flag) => {
      const item = document.createElement("li")
      item.textContent = this.linterMessagesValue[flag]
      this.warningListTarget.appendChild(item)
    })
  }

  syncMedia() {
    const imageSource = this.currentImageSource()
    const videoSource = this.currentVideoSource()

    if (this.hasPreviewImageSectionTarget) {
      this.previewImageTarget.src = imageSource || ""
      this.previewImageSectionTarget.classList.toggle("is-hidden", !imageSource)
    }

    if (this.hasPreviewVideoSectionTarget) {
      this.previewVideoTarget.src = videoSource || ""
      this.previewVideoSectionTarget.classList.toggle("is-hidden", !videoSource)
    }

    if (this.hasPreviewMediaEmptyTarget) {
      this.previewMediaEmptyTarget.classList.toggle("is-hidden", Boolean(imageSource || videoSource))
    }
  }

  currentImageSource() {
    if (!this.hasPreviewImageTarget) return null
    if (this.hasRemoveImageInputTarget && this.removeImageInputTarget.checked) return null

    if (this.hasImageInputTarget && this.imageInputTarget.files.length > 0) {
      this.revokeImageObjectUrl()
      this.imageObjectUrl = URL.createObjectURL(this.imageInputTarget.files[0])
      return this.imageObjectUrl
    }

    return this.existingImageUrlValue || null
  }

  currentVideoSource() {
    if (!this.hasPreviewVideoTarget) return null
    if (this.hasRemoveVideoInputTarget && this.removeVideoInputTarget.checked) return null

    if (this.hasVideoInputTarget && this.videoInputTarget.files.length > 0) {
      this.revokeVideoObjectUrl()
      this.videoObjectUrl = URL.createObjectURL(this.videoInputTarget.files[0])
      return this.videoObjectUrl
    }

    return this.existingVideoUrlValue || null
  }

  detectFlags(content) {
    const rules = {
      repeated_emoji_sequences: /(?:\p{Extended_Pictographic}\s*){2,}/u,
      revolutionize: /\brevolutionize(?:d|s|ing)?\b/i,
      game_changer: /\bgame[\s-]changer\b/i,
      disrupt: /\bdisrupt(?:s|ed|ing)?\b/i,
      ten_x: /\b10x\b/i,
      unicorn: /\bunicorn\b/i,
      world_class: /\bworld-class\b/i,
      best_in_class: /\bbest-in-class\b/i,
      groundbreaking: /\bgroundbreaking\b/i,
      next_gen: /\bnext-gen\b/i,
      seamless: /\bseamless\b/i,
      all_caps_word_runs: /\b[A-Z]{4,}\b/,
      multiple_exclamation_marks: /!!+/,
      exaggerated_urgency: /\b(?:act now|limited time|don't miss|last chance|available now|launching now|sign up today)\b/i
    }

    return Object.entries(rules)
      .filter(([, pattern]) => pattern.test(content))
      .map(([flag]) => flag)
  }

  revokeObjectUrls() {
    this.revokeImageObjectUrl()
    this.revokeVideoObjectUrl()
  }

  revokeImageObjectUrl() {
    if (this.imageObjectUrl) {
      URL.revokeObjectURL(this.imageObjectUrl)
      this.imageObjectUrl = null
    }
  }

  revokeVideoObjectUrl() {
    if (this.videoObjectUrl) {
      URL.revokeObjectURL(this.videoObjectUrl)
      this.videoObjectUrl = null
    }
  }
}
