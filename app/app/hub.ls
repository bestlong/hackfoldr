angular.module 'hub.g0v.tw' <[ui.state firebase]>

.controller TagControl: <[$scope $state Hub]> ++ ($scope, $state, Hub) ->
  $scope.$watch '$state.params.tag' (tag) ->
    $scope.tag = tag
  $scope <<< do
    projects:
      * name: \立法院
      * name: \meta
    people: Hub.people

.controller PeopleCtrl: <[$scope $state Hub angularFire]> ++ ($scope, $state, Hub, angularFire) ->
    $scope <<< do
        add_tag: (person) ->
            person.tags ?= []
            # XXX check duplicated
            person.tags.push $scope.newtag
            $scope.newtag = ''
            return false
        projects:
          * name: \立法院
          * name: \meta
        people: Hub.people
        auth: Hub.auth
        set-username: Hub.set-username
    $scope.$on 'event:auth-login' (e, {user}) ->
        console.log user
        fn = ->
            promise = angularFire Hub.root.child("people/#{user.username}"), $scope, 'user', {}
            $scope.toSetUsername = false
        phase = $scope.$root.$$phase;
        if (phase is '$apply' || phase is '$digest')
            fn!
        else
            $scope.$apply fn
    $scope.$on 'event:auth-logout' -> $scope.$apply ->
        $scope.user = null
        $scope.toSetUsername = false
    $scope.$on 'event:auth-userNameRequired' (e, {existing}) -> $scope.$apply ->
        $scope.toSetUsername = true
        $scope.userNameInUse = existing
        $scope.newUsername = Hub.auth-user?username
        if existing
            console.log \usernameinuse existing
        else
            console.log \usernameavailable Hub.auth-user

.factory Hub: <[$http angularFireCollection $rootScope]> ++ ($http, angularFireCollection, $rootScope) ->
    url = window.global.config.FIREBASE
    myDataRef = new Firebase(url)
    people = angularFireCollection myDataRef.child \people
    self = {}
    self.set-username = (username) ->
        return unless self.auth-user
        myDataRef
            ..child "auth-map/#{self.auth-user.provider}/#{self.auth-user.id}" .set {username}
            ..child "people/#{username}" .set self.auth-user{bio, displayName, emails} <<< {tags: [], username}
            ..child "people/#{username}/auth/#{self.auth-user.provider}" .set self.auth-user{id, username}
        login-user <- myDataRef.child "people/#{username}" .once \value
        self.login-user = login-user.val!
        $rootScope.$broadcast 'event:auth-login', user: self.login-user

    self.auth = new FirebaseAuthClient myDataRef, (error, user) ->
        if error
            console.log error
        else if user
            self.auth-user = user
            auth <- myDataRef.child "auth-map/#{user.provider}/#{user.id}" .once \value
            if {username}? = auth.val!
                console.log \usernameset
                login-user <- myDataRef.child "people/#{username}" .once \value
                self.login-user = login-user.val!
                $rootScope.$broadcast 'event:auth-login', user: self.login-user
            else
                inuse <- myDataRef.child "people/#{self.auth-user.username}" .once \value
                existing = inuse.val!
                $rootScope.$broadcast 'event:auth-userNameRequired', {existing}
        else
            $rootScope.$broadcast 'event:auth-logout'
    self <<< do
        root: myDataRef
        people: people
        register: ->
            person = do
              name: \clkao
              github: \clkao
              twitter: \clkao
              tags: <[ly g0v hackath3n livescript]>
              status: \available
            user = myDataRef.child "people/#{person.name}"
            me <- user.once \value
            unless me.val!
                user.set person
