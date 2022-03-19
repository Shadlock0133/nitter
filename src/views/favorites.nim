# SPDX-License-Identifier: AGPL-3.0-only
import std/[sugar, options]
import asyncdispatch, strformat, sequtils, times
import karax/[karaxdsl, vdom, vstyles]

from tweet import renderMiniAvatar
import ".."/[api, formatters, redis_cache, types]

proc getLatestTimestamp(timeline: Timeline): Option[DateTime] =
  if timeline.content.len == 0:
    return none(DateTime)
  timeline.content.mapIt(it.time).max.some

type TimeScale = enum
  SubSec, Secs, Mins, Hours, Days, Years

proc getShortTime(time: DateTime): (string, TimeScale) =
  let now = now()
  let since = now - time

  result = if now.year != time.year:
    (time.format("d MMM yyyy"), TimeScale.Years)
  elif since.inDays >= 1:
    (time.format("MMM d"), TimeScale.Days)
  elif since.inHours >= 1:
    ($since.inHours & "h", TimeScale.Hours)
  elif since.inMinutes >= 1:
    ($since.inMinutes & "m", TimeScale.Mins)
  elif since.inSeconds > 1:
    ($since.inSeconds & "s", TimeScale.Secs)
  else:
    ("now", TimeScale.SubSec)

type Favorite = (User, Option[DateTime])

proc awaitAll[T](futs: seq[Future[T]]): Future[seq[T]] {.async.} =
  let _ = futs.all.await
  result = futs.mapIt(it.read)

proc getFavorite(username: string, withTimestamp: bool): Future[Favorite] {.async.} =
  let user = getCachedUser(username).await
  let latest = if withTimestamp:
    let timeline = getTimeline(user.id).await
    timeline.getLatestTimestamp
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
          # TODO: Mark protected accounts?
          a(href= &"/{username}"): renderMiniAvatar(user, prefs)
          a(class="fullname", href= &"/{username}"): text &"{fullname}"
          a(class="username", href= &"/{username}"): text &"@{username}"
          if latest.isSome:
            let (t, s) = latest.get.getShortTime
            let amount = case s:
              of TimeScale.SubSec: "100%"
              of TimeScale.Secs: "90%"
              of TimeScale.Mins: "80%"
              of TimeScale.Hours: "70%"
              of TimeScale.Days: "60%"
              of TimeScale.Years: "50%"
            let style: VStyle = style(
              color,
              &"color-mix(in srgb, var(--accent) {amount}, black)"
            )
            # Using `Option::isSome` and `Option::get`, because no native pattern matching
            a(style=style, title=latest.get.getTime, href= &"/{username}"):
              text t
