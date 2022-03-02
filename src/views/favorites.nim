# SPDX-License-Identifier: AGPL-3.0-only
import std/[sugar, options]
import asyncdispatch, strformat, sequtils, times
import karax/[karaxdsl, vdom]

from tweet import renderMiniAvatar
import ".."/[api, formatters, redis_cache, types]

proc getLatestTimestamp(timeline: Timeline): DateTime =
  timeline.content.mapIt(it.time).max

type Favorite = (User, Option[DateTime])

proc getUsers*(prefs: Prefs): Future[seq[Favorite]] {.async.} =
  result = collect:
    for line in lines "favorites":
      let
        username = line
        user = getCachedUser(username).await
      let latest = if prefs.favoritesTimestamps:
        let timeline = getTimeline(user.id).await
        timeline.getLatestTimestamp.some
      else: none(DateTime)
      (user, latest)

proc renderFavorites*(users: seq[Favorite], prefs: Prefs): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="favorite-list"):
      for (user, latest) in users:
        let
          username = user.username
          fullname = user.fullname
        tdiv(class="user"):
          a(href= &"/{username}"): renderMiniAvatar(user, prefs)
          a(class="fullname", href= &"/{username}"): text &"{fullname}"
          a(class="username", href= &"/{username}"): text &"@{username}"
          if latest.isSome:
            a(title=latest.get.getTime): text latest.get.getShortTime
