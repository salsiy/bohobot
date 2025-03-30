#!/bin/bash

# Hugo Blowfish Theme Setup Script
# Creates directory structure and files for a professional minimal website

# Check if we're in a Hugo project root
if [ ! -f "hugo.toml" ] && [ ! -f "config.toml" ]; then
  echo "Error: This doesn't appear to be a Hugo project root directory."
  echo "Please run this script from your Hugo project's root."
  exit 1
fi

# Create directories
mkdir -p content/{posts/{india-life,poland-life,devops},assets/images} config/_default

# Create config files
cat << 'EOF' > config/_default/hugo.toml
baseURL = "https://yourdomain.com/"
languageCode = "en"
defaultContentLanguage = "en"
title = "Your Name"
theme = "blowfish"

[build]
  writeStats = true

[imaging]
  quality = 85
  resampleFilter = "CatmullRom"
  anchor = "smart"

[markup.goldmark.renderer]
  unsafe = true

[params]
  description = "Personal website documenting my life in India and Poland, and my DevOps journey"
  author = "Your Name"
  keywords = ["devops", "india", "poland", "technology", "blog"]
  colorScheme = "autumn"
  defaultTheme = "light"
  enableSearch = true
EOF

cat << 'EOF' > config/_default/menus.en.toml
[[main]]
  name = "Home"
  pageRef = "/"
  weight = 10

[[main]]
  name = "About"
  pageRef = "/about"
  weight = 20

[[main]]
  name = "India Life"
  pageRef = "/posts/india-life"
  weight = 30

[[main]]
  name = "Poland Life"
  pageRef = "/posts/poland-life"
  weight = 40

[[main]]
  name = "DevOps"
  pageRef = "/posts/devops"
  weight = 50

[[main]]
  name = "Contact"
  pageRef = "/contact"
  weight = 60
EOF

cat << 'EOF' > config/_default/params.toml
[appearance]
  showThemeToggle = true

[homepage]
  layout = "profile"
  showRecent = true
  showRecentItems = 6
  recentHeading = "Latest Stories"
  profilePhoto = "images/profile.jpg"
  profileAlt = "Your Name"
  profileSubtitle = "DevOps Engineer | India & Poland Stories"

[article]
  showDate = true
  showAuthor = true
  showBreadcrumbs = true
  showDraftLabel = true
  showReadingTime = true
  showTableOfContents = true
  showTaxonomies = true
  showWordCount = true
  taxonomies = ["tags", "categories"]

[header]
  layout = "fixed"
  sticky = true
  showTitle = true

[footer]
  showCopyright = true
  showThemeAttribution = true
  showAppearanceSwitcher = true
  showScrollToTop = true
  copyrightText = "© {year} Your Name. All rights reserved."

[social]
  email = "your.email@example.com"
  github = "yourgithubusername"
  linkedin = "yourlinkedinusername"
  rss = true

[params]
  contactMessage = "Feel free to reach out for collaborations or just to say hello!"
  googleAnalytics = "UA-XXXXX"
  plausibleAnalytics = ""

  [params.comments]
    enabled = false
    provider = "disqus"
EOF

# Create content files
cat << 'EOF' > content/_index.md
---
title: "Welcome"
description: "Personal website of Your Name"
---

Hi, I'm **Your Name**. 

This is my personal space where I share stories about my life in India and Poland, and write about my DevOps journey.

Explore my [India stories](/posts/india-life), [Poland experiences](/posts/poland-life), or read my [technical articles](/posts/devops).
EOF

cat << 'EOF' > content/about.md
---
title: "About Me"
description: "Learn more about my journey"
---

I'm a DevOps engineer currently living in Poland with roots in India. 

This website documents my personal and professional journey across cultures and technologies.

## My Background

- Born and raised in India
- Moved to Poland in [year]
- Working in IT/DevOps since [year]
- Passionate about [your interests]

## Skills

- Cloud Technologies: AWS, Azure, GCP
- Containerization: Docker, Kubernetes
- CI/CD: Jenkins, GitHub Actions
- Infrastructure as Code: Terraform, Ansible
EOF

cat << 'EOF' > content/contact.md
---
title: "Contact"
description: "Get in touch with me"
---

{{< social >}}

Feel free to reach out via email or connect with me on professional networks.

## Direct Contact

- **Email**: [your.email@example.com](mailto:your.email@example.com)
- **Location**: Warsaw, Poland (originally from [Your City], India)

## Professional Profiles

- [LinkedIn](https://linkedin.com/in/yourprofile)
- [GitHub](https://github.com/yourusername)
EOF

# Create post index files
cat << 'EOF' > content/posts/_index.md
---
title: "All Posts"
description: "Collection of all articles"
---
EOF

cat << 'EOF' > content/posts/india-life/_index.md
---
title: "Life in India"
description: "Stories from my Indian life"
---
EOF

cat << 'EOF' > content/posts/poland-life/_index.md
---
title: "Life in Poland"
description: "Stories from my Polish life"
---
EOF

cat << 'EOF' > content/posts/devops/_index.md
---
title: "DevOps Articles"
description: "Technical articles about DevOps"
---
EOF

# Create sample posts
cat << 'EOF' > content/posts/india-life/first-post.md
---
title: "My First Memories of India"
date: 2023-10-15
description: "Recollections of my early life in India"
tags: ["india", "memories", "childhood"]
categories: ["India Life"]
draft: false
---

## Growing Up in [Your City]

This is where your content begins. Write about your early memories, family life, education, or anything that shaped your Indian experience.

### Cultural Experiences

Share specific cultural aspects that were meaningful to you:

- Festivals you celebrated
- Food you loved
- Traditions in your family

## Moving Away

Describe your transition from India to Poland and how it felt to leave.
EOF

cat << 'EOF' > content/posts/poland-life/first-post.md
---
title: "My First Impressions of Poland"
date: 2023-10-16
description: "Initial experiences after moving to Poland"
tags: ["poland", "immigration", "culture"]
categories: ["Poland Life"]
draft: false
---

## Arriving in Poland

Describe your first days in Poland - the weather, people, language challenges, etc.

### Cultural Differences

Compare with your Indian background:

- Work culture
- Social interactions
- Food habits

## Settling In

How you adapted to life in Poland over time.
EOF

cat << 'EOF' > content/posts/devops/first-post.md
---
title: "Getting Started with DevOps"
date: 2023-10-17
description: "Introduction to DevOps practices"
tags: ["devops", "ci/cd", "automation"]
categories: ["DevOps"]
draft: false
---

## What is DevOps?

Explain the concept and why it's important in modern software development.

### Key Components

- Continuous Integration/Continuous Deployment (CI/CD)
- Infrastructure as Code
- Monitoring and Logging

## My DevOps Journey

Share your personal experience learning and working with DevOps tools.
EOF

# Create custom CSS file
mkdir -p assets/css
cat << 'EOF' > assets/css/custom.css
/* Custom font sizes */
.profile-subtitle {
  font-size: 1.1rem;
}

/* Better spacing for articles */
article {
  line-height: 1.6;
}

/* Social icons styling */
.social-icons {
  margin-top: 2rem;
}
EOF

# Create empty profile image placeholder
touch assets/images/profile.jpg

echo "Setup complete!"
echo "Don't forget to:"
echo "1. Replace placeholder values in the configuration files"
echo "2. Add your actual profile photo at assets/images/profile.jpg"
echo "3. Customize the content in the markdown files"