class ContentDisplayDiscussion extends KDView

  constructor:(options = {}, data)->

    options.tooltip or=
      title     : "Discussion"
      offset    : 3
      selector  : "span.type-icon"

    super options, data

    @setClass 'activity-item discussion'

    origin =
      constructorName  : data.originType
      id               : data.originId

    @avatar = new AvatarStaticView
      tagName : "span"
      size    : {width: 50, height: 50}
      origin  : origin

    @author = new ProfileLinkView {origin:origin}

    @opinionBox = new OpinionView null, data

    @opinionBoxHeader = new KDCustomHTMLView
      tagName : "div"
      cssClass : "opinion-box-header"
      partial : @opinionHeaderCountString data.repliesCount

    @opinionBox.opinionList.on "OwnOpinionHasArrived", (data)=>
      @opinionBoxHeader.updatePartial @opinionHeaderCountString @getData().repliesCount

    @opinionBox.opinionList.on "OpinionIsDeleted", (data)=>
      @opinionBoxHeader.updatePartial @opinionHeaderCountString @getData().repliesCount

    @opinionForm = new OpinionFormView
      cssClass : "opinion-container"
      callback  : (data)=>
        @getData().reply data, (err, opinion) =>
          callback? err, opinion
          if err
            new KDNotificationView type : "mini", title : "There was an error, try again later!"
          else
            @opinionBox.opinionList.emit "OwnOpinionHasArrived", opinion
    , data

    @actionLinks = new DiscussionActivityActionsView
      delegate : @opinionBox.opinionList
      cssClass : "comment-header"
    , data

    @tags = new ActivityChildViewTagGroup
      itemsToShow   : 3
      subItemClass  : TagLinkView
    , data.tags

    @deleteDiscussionLink = new KDCustomHTMLView
      tagName     : 'a'
      attributes  :
        title     : "Delete your discussion"
        href      : '#'
      cssClass    : 'delete-link hidden'

    @editDiscussionLink = new KDCustomHTMLView
      tagName     : 'a'
      attributes  :
        title     : "Edit your discussion"
        href      : '#'
      cssClass    : 'edit-link hidden'

    # activity = @getDelegate().getData()
    bongo.cacheable data.originId, "JAccount", (err, account)=>
      loggedInId = KD.whoami().getId()
      if loggedInId is data.originId or       # if comment owner
         # loggedInId is activity.originId or   # if activity owner
         KD.checkFlag "super-admin", account  # if super-admin

        @listenTo
          KDEventTypes       : "click"
          listenedToInstance : @editDiscussionLink
          callback           : =>
            if @editDiscussionForm?
              @editDiscussionForm?.destroy()
              delete @editDiscussionForm
              @$(".discussion-body .data").show()
            else
              @editDiscussionForm = new DiscussionFormView
                title : "edit-discussion"
                cssClass : "edit-discussion-form"
                callback : (data)=>
                  @getData().modify data, (err, discussion) =>
                    callback? err, opinion
                    if err
                      new KDNotificationView title : "Your changes weren't saved.", type :"mini"
                    else
                      @emit "DiscussionWasEdited", discussion
                      @editDiscussionForm.setClass "hidden"
              , data


              @addSubView @editDiscussionForm, "p.discussion-body", yes
              @$(".discussion-body .data").hide()

        @listenTo
          KDEventTypes       : "click"
          listenedToInstance : @deleteDiscussionLink
          callback           : => @confirmDeleteDiscussion data

        @editDiscussionLink.unsetClass "hidden"
        @deleteDiscussionLink.unsetClass "hidden"

  opinionHeaderCountString:(count)=>
    if count is 0
      countString = "No Answers yet"
    else if count is 1
      countString = "One Answer"
    else
      countString = count+ " Answers"
    '<span class="opinion-count">'+countString+'</span>'

  confirmDeleteDiscussion:(data)->

    modal = new KDModalView
      title          : "Delete discussion"
      content        : "<div class='modalformline'>Are you sure you want to delete this discussion and all it's opinions and comments?</div>"
      height         : "auto"
      overlay        : yes
      buttons        :
        Delete       :
          style      : "modal-clean-red"
          loader     :
            color    : "#ffffff"
            diameter : 16
          callback   : =>
            data.delete (err)=>
              modal.buttons.Delete.hideLoader()
              modal.destroy()
              unless err
                @emit 'DiscussionIsDeleted'
                @destroy()
              else new KDNotificationView
                type     : "mini"
                cssClass : "error editor"
                title     : "Error, please try again later!"

  viewAppended:()->
    super()
    @setTemplate @pistachio()
    @template.update()

    # temp for beta
    # take this bit to comment view
    # this is useful when the snaphots don't work
    # if @getData().repliesCount? and @getData().repliesCount > 0
    #   opinionController = @opinionBox.opinionController
    #   opinionController.fetchRelativeOpinions 5, 0, (err, opinions)=>
    #     for opinion in opinions
    #       @opinionBox.opinionList.addItem opinion, null, {type : "slideDown", duration : 100}
    #     @opinionBox.opinionList.emit "RelativeOpinionsWereAdded"

  pistachio:->
    """
    <div class='discussion-contents'>
    <div class="discussion-content">
      <span>
        {{> @avatar}}
        <span class="author">AUTHOR</span>
      </span>
      <div class='discussion-main-opinion'>

        <h3>{{#(title)}}</h3>

        <footer class='discussion-footer clearfix'>
          <div class='type-and-time'>
            <span class='type-icon'></span> by {{> @author}} •
            <time>{{$.timeago #(meta.createdAt)}}</time>
            {{> @tags}}
                  {{> @actionLinks}}
          </div>
        </footer>
        {{> @editDiscussionLink}}
        {{> @deleteDiscussionLink}}
        <p class='context discussion-body'>{{@utils.expandUsernames @utils.applyMarkdown #(body)}}</p>
      </div>
    </div>
    </div>
    <div class="opinion-content">
    {{> @opinionBoxHeader}}
    {{> @opinionBox}}
    <div class="content-display-main-section opinion-form-footer">
        {{> @opinionForm}}
    </div>
    </div>

    """
