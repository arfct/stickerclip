---
title: Stickerclip
date: 2022-07
status: released
category: product
tags: [ios]
url: https://stickerclip.app
links:
  app_store: https://apps.apple.com/app/id1633833395
  source: https://github.com/arfct/stickerclip
media:
  - src: site.png
    caption: The product's site, where a phone shows a bordered sticker placed on a message, above the app's drawer in Messages with its border and size buttons
    alt: A yellow web page with a white clipboard logo and the word stickerclip, beside a phone screen in which an emoji sticker with a white border overlaps a blue message bubble above an empty sticker drawer
  - src: steps.png
    caption: The site's instructions, with the drawer holding a pasted emoji and, at the right, the Copy command over a photo of a dog
    alt: A web page headed Make stickers from the clipboard, with a picture of the sticker drawer holding an emoji, short paragraphs titled Add a border and Change size, and a phone photo of a bulldog in a red costume under a Copy and Share menu
credits: [alcor]
unconfirmed: [credits, status]
---

Stickerclip's first version took its images from one place, the clipboard. An image copied anywhere and then pasted into the app's drawer in Messages becomes an iMessage sticker, which can be given a white border with a soft shadow and one of six sizes. Copied text becomes a sticker as well, set in bold type that is twice as large when the text is three characters or fewer. On the product's site, in the first image, a phone shows a bordered sticker placed on a message.

Stickerclip has been on the App Store since July 2022 and is free; the current version, 1.1.1, does not work on iOS 26. A rebuild, version 2.0, is in the repository and not on the App Store. Its drawer also takes images from Photos and Files, fetches the image when the clipboard holds only a link to one, and keeps an animated GIF animated, where version 1 reduced one to a single frame whenever it added a border or resized the image.

Swift, UIKit, SwiftUI. 2022.
