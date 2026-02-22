---
title: TailwindCSS implementation of Human Interface Guidelines
tags: [frontend]
---

```css
@import "tailwindcss";

/* Colors: https://developer.apple.com/design/human-interface-guidelines/color#Specifications */
:root {
  --red: rgb(255 56 60);
  --orange: rgb(255 141 40);
  --yellow: rgb(255 204 0);
  --green: rgb(52 199 89);
  --mint: rgb(0 200 179);
  --teal: rgb(0 195 208);
  --cyan: rgb(0 192 232);
  --blue: rgb(0 136 255);
  --indigo: rgb(97 85 245);
  --purple: rgb(203 48 224);
  --pink: rgb(255 45 85);
  --brown: rgb(172 127 94);

  @variant dark {
    --red: rgb(255 66 69);
    --orange: rgb(255 146 48);
    --yellow: rgb(255 214 0);
    --green: rgb(48 209 88);
    --mint: rgb(0 218 195);
    --teal: rgb(0 210 224);
    --cyan: rgb(60 211 254);
    --blue: rgb(0 145 255);
    --indigo: rgb(109 124 255);
    --purple: rgb(219 52 242);
    --pink: rgb(255 55 95);
    --brown: rgb(183 138 102);
  }

  --gray: rgb(142 142 147);
  --gray2: rgb(174 174 178);
  --gray3: rgb(199 199 204);
  --gray4: rgb(209 209 214);
  --gray5: rgb(229 229 234);
  --gray6: rgb(242 242 247);

  @variant dark {
    --gray: rgb(142 142 147);
    --gray2: rgb(99 99 102);
    --gray3: rgb(72 72 74);
    --gray4: rgb(58 58 60);
    --gray5: rgb(44 44 46);
    --gray6: rgb(28 28 30);
  }

  @variant contrast-more {
    --red: rgb(233 21 45);
    --orange: rgb(197 83 0);
    --yellow: rgb(161 106 0);
    --green: rgb(0 137 50);
    --mint: rgb(0 133 117);
    --teal: rgb(0 129 152);
    --cyan: rgb(0 126 174);
    --blue: rgb(30 110 244);
    --indigo: rgb(86 74 222);
    --purple: rgb(176 47 194);
    --pink: rgb(231 18 77);
    --brown: rgb(149 109 81);

    @variant dark {
      --red: rgb(255 97 101);
      --orange: rgb(255 160 86);
      --yellow: rgb(254 223 67);
      --green: rgb(74 217 104);
      --mint: rgb(84 223 203);
      --teal: rgb(59 221 236);
      --cyan: rgb(109 217 255);
      --blue: rgb(92 184 255);
      --indigo: rgb(167 170 255);
      --purple: rgb(234 141 255);
      --pink: rgb(255 138 196);
      --brown: rgb(219 166 121);
    }

    --gray: rgb(108 108 112);
    --gray2: rgb(142 142 147);
    --gray3: rgb(174 174 178);
    --gray4: rgb(188 188 192);
    --gray5: rgb(216 216 220);
    --gray6: rgb(235 235 240);

    @variant dark {
      --gray: rgb(174 174 178);
      --gray2: rgb(124 124 128);
      --gray3: rgb(84 84 86);
      --gray4: rgb(68 68 70);
      --gray5: rgb(54 54 56);
      --gray6: rgb(36 36 38);
    }
  }
}

@theme inline {
  --color-red: var(--red);
  --color-orange: var(--orange);
  --color-yellow: var(--yellow);
  --color-green: var(--green);
  --color-mint: var(--mint);
  --color-teal: var(--teal);
  --color-cyan: var(--cyan);
  --color-blue: var(--blue);
  --color-indigo: var(--indigo);
  --color-purple: var(--purple);
  --color-pink: var(--pink);
  --color-brown: var(--brown);

  --color-gray: var(--gray);
  --color-gray2: var(--gray2);
  --color-gray3: var(--gray3);
  --color-gray4: var(--gray4);
  --color-gray5: var(--gray5);
  --color-gray6: var(--gray6);
}

/* Typography: https://developer.apple.com/design/human-interface-guidelines/typography#Specifications */
:root {
  font-size: var(--text-body);

  --large-title-size: 34pt;
  --title1-size: 28pt;
  --title2-size: 22pt;
  --title3-size: 20pt;
  --headline-size: 17pt;
  --body-size: 17pt;
  --callout-size: 16pt;
  --sub-headline-size: 15pt;
  --footnote-size: 13pt;
  --caption1-size: 12pt;
  --caption2-size: 11pt;

  --large-title-leading: 41pt;
  --title1-leading: 34pt;
  --title2-leading: 28pt;
  --title3-leading: 25pt;
  --headline-leading: 22pt;
  --body-leading: 22pt;
  --callout-leading: 21pt;
  --sub-headline-leading: 20pt;
  --footnote-leading: 18pt;
  --caption1-leading: 16pt;
  --caption2-leading: 13pt;

  --large-title-strong: var(--font-weight-bold);
  --title1-strong: var(--font-weight-bold);
  --title2-strong: var(--font-weight-bold);
  --title3-strong: var(--font-weight-semibold);
  --headline-strong: var(--font-weight-semibold);
  --body-strong: var(--font-weight-semibold);
  --callout-strong: var(--font-weight-semibold);
  --sub-headline-strong: var(--font-weight-semibold);
  --footnote-strong: var(--font-weight-semibold);
  --caption1-strong: var(--font-weight-semibold);
  --caption2-strong: var(--font-weight-semibold);

  --large-title-tracking: 0.4pt;
  --title1-tracking: 0.38pt;
  --title2-tracking: -0.26pt;
  --title3-tracking: -0.45pt;
  --headline-tracking: -0.43pt;
  --body-tracking: -0.43pt;
  --callout-tracking: -0.31pt;
  --sub-headline-tracking: -0.23pt;
  --footnote-tracking: -0.08pt;
  --caption1-tracking: 0pt;
  --caption2-tracking: 0.06pt;

  @variant sm {
    --large-title-size: 26pt;
    --title1-size: 22pt;
    --title2-size: 17pt;
    --title3-size: 15pt;
    --headline-size: 13pt;
    --body-size: 13pt;
    --callout-size: 12pt;
    --sub-headline-size: 11pt;
    --footnote-size: 10pt;
    --caption1-size: 10pt;
    --caption2-size: 10pt;

    --large-title-leading: 32pt;
    --title1-leading: 26pt;
    --title2-leading: 22pt;
    --title3-leading: 20pt;
    --headline-leading: 16pt;
    --body-leading: 16pt;
    --callout-leading: 15pt;
    --sub-headline-leading: 14pt;
    --footnote-leading: 13pt;
    --caption1-leading: 13pt;
    --caption2-leading: 13pt;

    --large-title-strong: var(--font-weight-bold);
    --title1-strong: var(--font-weight-bold);
    --title2-strong: var(--font-weight-bold);
    --title3-strong: var(--font-weight-semibold);
    --headline-strong: var(--font-weight-black);
    --body-strong: var(--font-weight-semibold);
    --callout-strong: var(--font-weight-semibold);
    --sub-headline-strong: var(--font-weight-semibold);
    --footnote-strong: var(--font-weight-semibold);
    --caption1-strong: var(--font-weight-medium);
    --caption2-strong: var(--font-weight-semibold);

    --large-title-tracking: 0.22pt;
    --title1-tracking: -0.26pt;
    --title2-tracking: -0.43pt;
    --title3-tracking: -0.23pt;
    --headline-tracking: -0.08pt;
    --body-tracking: -0.08pt;
    --callout-tracking: 0pt;
    --sub-headline-tracking: 0.06pt;
    --footnote-tracking: 0.12pt;
    --caption1-tracking: 0.12pt;
    --caption2-tracking: 0.12pt;
  }
}

@theme inline {
  --text-large-title: var(--large-title-size);
  --text-title1: var(--title1-size);
  --text-title2: var(--title2-size);
  --text-title3: var(--title3-size);
  --text-headline: var(--headline-size);
  --text-body: var(--body-size);
  --text-callout: var(--callout-size);
  --text-sub-headline: var(--sub-headline-size);
  --text-footnote: var(--footnote-size);
  --text-caption1: var(--caption1-size);
  --text-caption2: var(--caption2-size);

  --leading-large-title: var(--large-title-leading);
  --leading-title1: var(--title1-leading);
  --leading-title2: var(--title2-leading);
  --leading-title3: var(--title3-leading);
  --leading-headline: var(--headline-leading);
  --leading-body: var(--body-leading);
  --leading-callout: var(--callout-leading);
  --leading-sub-headline: var(--sub-headline-leading);
  --leading-footnote: var(--footnote-leading);
  --leading-caption1: var(--caption1-leading);
  --leading-caption2: var(--caption2-leading);

  --font-weight-large-title-strong: var(--large-title-strong);
  --font-weight-title1-strong: var(--title1-strong);
  --font-weight-title2-strong: var(--title2-strong);
  --font-weight-title3-strong: var(--title3-strong);
  --font-weight-headline-strong: var(--headline-strong);
  --font-weight-body-strong: var(--body-strong);
  --font-weight-callout-strong: var(--callout-strong);
  --font-weight-sub-headline-strong: var(--sub-headline-strong);
  --font-weight-footnote-strong: var(--footnote-strong);
  --font-weight-caption1-strong: var(--caption1-strong);
  --font-weight-caption2-strong: var(--caption2-strong);

  --tracking-large-title: var(--large-title-tracking);
  --tracking-title1: var(--title1-tracking);
  --tracking-title2: var(--title2-tracking);
  --tracking-title3: var(--title3-tracking);
  --tracking-headline: var(--headline-tracking);
  --tracking-body: var(--body-tracking);
  --tracking-callout: var(--callout-tracking);
  --tracking-sub-headline: var(--sub-headline-tracking);
  --tracking-footnote: var(--footnote-tracking);
  --tracking-caption1: var(--caption1-tracking);
  --tracking-caption2: var(--caption2-tracking);
}

@custom-variant strong (& strong);

@utility large-title {
  @apply text-large-title leading-large-title tracking-large-title;
  @apply strong:font-large-title-strong;
}

@utility title1 {
  @apply text-title1 leading-title1 tracking-title1;
  @apply strong:font-title1-strong;
}

@utility title2 {
  @apply text-title2 leading-title2 tracking-title2;
  @apply strong:font-title2-strong;
}

@utility title3 {
  @apply text-title3 leading-title3 tracking-title3;
  @apply strong:font-title3-strong;
}

@utility headline {
  @apply text-headline leading-headline tracking-headline;
  @apply strong:font-headline-strong;
}

@utility body {
  @apply text-body leading-body tracking-body;
  @apply strong:font-body-strong;
}

@utility callout {
  @apply text-callout leading-callout tracking-callout;
  @apply strong:font-callout-strong;
}

@utility sub-headline {
  @apply text-sub-headline leading-sub-headline tracking-sub-headline;
  @apply strong:font-sub-headline-strong;
}

@utility footnote {
  @apply text-footnote leading-footnote tracking-footnote;
  @apply strong:font-footnote-strong;
}

@utility caption1 {
  @apply text-caption1 leading-caption1 tracking-caption1;
  @apply strong:font-caption1-strong;
}

@utility caption2 {
  @apply text-caption2 leading-caption2 tracking-caption2;
  @apply strong:font-caption2-strong;
}
```