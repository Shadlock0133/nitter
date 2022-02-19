# SPDX-License-Identifier: AGPL-3.0-only
import std/sugar
import asyncdispatch, strformat
import karax/[karaxdsl, vdom]

from tweet import renderMiniAvatar
import ".."/[redis_cache, types]

proc getUsers*(): Future[seq[User]] {.async.} =
  result = collect:
    for line in lines "favorites":
      let username = line
      getCachedUser(username).await

proc renderFavorites*(users: seq[User], prefs: Prefs): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="favorite-list"):
      for user in users:
        let
          username = user.username
          fullname = user.fullname
        tdiv(class="user"):
          a(href= &"/{username}"): renderMiniAvatar(user, prefs)
          a(class="fullname", href= &"/{username}"): text &"{fullname}"
          a(class="username", href= &"/{username}"): text &"@{username}"
