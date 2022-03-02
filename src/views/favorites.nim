# SPDX-License-Identifier: AGPL-3.0-only
import std/[sugar, options]
import asyncdispatch, strformat, sequtils, times
import karax/[karaxdsl, vdom]

from tweet import renderMiniAvatar
import ".."/[api, formatters, redis_cache, types]

proc getLatestTimestamp(timeline: Timeline): DateTime =
  timeline.content.mapIt(it.time).max

type Favorite = (User, Option[DateTime])

proc awaitAll[T](futs: seq[Future[T]]): Future[seq[T]] {.async.} =
  let _ = futs.all.await
  result = futs.mapIt(it.read)

proc getFavorite(username: string, withTimestamp: bool): Future[Favorite] {.async.} =
  let user = getCachedUser(username).await
  let latest = if withTimestamp:
    let timeline = getTimeline(user.id).await
    timeline.getLatestTimestamp.some
  else: none(DateTime)
  result = (user, latest)

proc getUsers*(prefs: Prefs): Future[seq[Favorite]] {.async.} =
  let favorites = collect:
    for username in lines "favorites":
      getFavorite(username, prefs.favoritesTimestamps)
  result = favorites.awaitAll.await

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
