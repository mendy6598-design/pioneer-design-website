$ErrorActionPreference = 'Stop'

# Builds about.html and projects.html from the finished index.html so the
# header, footer, fonts and stylesheet stack stay byte-identical.
$root = 'D:\Simcha\The Pioneer Design Website'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$index = [IO.File]::ReadAllText((Join-Path $root 'index.html'))

$headEnd = $index.IndexOf('</head>') + '</head>'.Length
$head = $index.Substring(0, $headEnd)
$headerStart = $index.IndexOf('<header')
$headerEnd = $index.IndexOf('</header>') + '</header>'.Length
$header = $index.Substring($headerStart, $headerEnd - $headerStart)
$footerStart = $index.IndexOf('<footer')
$footerEnd = $index.IndexOf('</footer>') + '</footer>'.Length
$footer = $index.Substring($footerStart, $footerEnd - $footerStart)

$bodyClass = 'home blog wp-custom-logo wp-embed-responsive wp-theme-pubadventurer is-block-theme customizer-styles-applied jetpack-reblog-enabled pd-subpage'

function New-Head([string]$title) {
    $h = $head -replace '(?s)<title>.*?</title>', "<title>$title &#8211; Interior Design</title>"
    $h = $h.Replace('</head>', '<link rel="stylesheet" href="assets/css/pages.css?v=3" />' + "`r`n" + '</head>')
    return $h
}

$navSwap = @{
    'index.html'   = 'index.html'
    'about.html'   = 'about.html'
    'projects.html'= 'projects.html'
}

function New-Page([string]$title, [string]$main) {
    $headHtml = New-Head $title
    $body = @"
<body class="$bodyClass">

<div class="wp-site-blocks">
$header

$main

$footer</div>
<script src="assets/js/main.js?v=3"></script>
</body>
</html>
"@
    return $headHtml + "`r`n" + $body
}

# ---------------------------------------------------------------- ABOUT
$aboutMain = @'
<main class="pd-page">
    <section class="pd-hero">
        <div class="pd-wrap">
            <p class="pd-eyebrow">The Pioneer Design</p>
            <h1 class="pd-title">About</h1>
            <p class="pd-lede">Interior design &mdash; from inspiration to transformation.</p>
        </div>
    </section>

    <section class="pd-section">
        <div class="pd-wrap pd-split">
            <figure class="pd-figure pd-figure--tall">
                <img src="assets/img/643c97d4aea0a2206f8cd2dd5ed07741c4e76430.jpg" alt="Interior designed by The Pioneer Design" width="1500" height="2000" />
            </figure>
            <div class="pd-copy">
                <h2>Spaces with a point of view</h2>
                <p>The Pioneer Design is an interior design studio creating residential and commercial spaces that feel as good as they look. We believe a room should tell you something about the people who use it &mdash; their rituals, their tastes, the way they like to live.</p>
                <p>From striking focal points to subtle textures, every design element plays a part in that story. We balance proportion, material and light to build interiors that are calm, warm and quietly confident.</p>
                <p>Working closely with each client from the first conversation to the final installation, we keep the process personal, considered and clear.</p>
                <p class="pd-sign">&mdash; The Pioneer Design</p>
            </div>
        </div>
    </section>

    <section class="pd-section pd-section--cream">
        <div class="pd-wrap">
            <h2 class="pd-section-title">What we do</h2>
            <ul class="pd-services">
                <li><span class="pd-num">01</span><span>Interior design &amp; styling</span></li>
                <li><span class="pd-num">02</span><span>Space planning</span></li>
                <li><span class="pd-num">03</span><span>Material &amp; finish selection</span></li>
                <li><span class="pd-num">04</span><span>Furniture &amp; lighting sourcing</span></li>
                <li><span class="pd-num">05</span><span>Custom millwork &amp; furnishings</span></li>
                <li><span class="pd-num">06</span><span>Renovation consulting</span></li>
            </ul>
        </div>
    </section>

    <section class="pd-section">
        <div class="pd-wrap">
            <figure class="pd-figure">
                <img src="assets/img/6a04f1240e7a91404b82790897803e72c585544c.jpg" alt="A finished living space by The Pioneer Design" width="1600" height="900" />
            </figure>
        </div>
    </section>

    <section class="pd-section pd-section--cream">
        <div class="pd-wrap">
            <h2 class="pd-section-title">How we work</h2>
            <div class="pd-steps">
                <div class="pd-step">
                    <span class="pd-num">01</span>
                    <h3>Conversation</h3>
                    <p>We start by listening: how you live, what you love and what is not working.</p>
                </div>
                <div class="pd-step">
                    <span class="pd-num">02</span>
                    <h3>Concept</h3>
                    <p>Mood, palette and layout come together in a direction that feels unmistakably yours.</p>
                </div>
                <div class="pd-step">
                    <span class="pd-num">03</span>
                    <h3>Design</h3>
                    <p>Detailed drawings, finishes and selections &mdash; every decision documented and coordinated.</p>
                </div>
                <div class="pd-step">
                    <span class="pd-num">04</span>
                    <h3>Installation</h3>
                    <p>We manage the details through delivery and styling, so the finished space is ready to live in.</p>
                </div>
            </div>
        </div>
    </section>

    <section class="pd-cta">
        <div class="pd-wrap">
            <h2>Let&rsquo;s talk about your space</h2>
            <a class="pd-btn" href="index.html#contact">Get in touch</a>
        </div>
    </section>
</main>
'@

# -------------------------------------------------------------- PROJECTS
$galleryFiles = @(
    '79f6c6253040533e69ec6c01349cdd804b052776.jpg'
    '1bd28ee7c9fc922c814478ccbe8e2404266e44d2.jpg'
    'acb6b41c25e8625ea14bd9f158dfb7a65096bb1a.jpg'
    '6a04f1240e7a91404b82790897803e72c585544c.jpg'
    'e72521ce0831968aaa29a3f4afa8ecf5cb23f0d3.jpg'
    '4ea89efa6fd75e329dc77e5ec3de5887aef4d22a.jpg'
    'acf965101c8ab59b6ebc34d773b0360805219f15.jpg'
    '4bac52dcba1d9242edeccfeaabfa0e2ad3161218.jpg'
    '130423ec38b80de4dc7cf0edb880526798d09245.jpg'
    '5fc8420a7d5694560c1c2d3acb41ba513027fd58.jpg'
    '40365ee065829850eb601d890e8072f5db3f8141.jpg'
    '643c97d4aea0a2206f8cd2dd5ed07741c4e76430.jpg'
    '446cfa55b13cb96cff89f42270cce620040f0482.jpg'
    'b5d670c0a07c0b16cce8e6bf9b2882b5b859aae1.jpg'
    'ef61e907ec4130954ab55453fe7a58f1fd7c4638.jpg'
    '97c90f413a89680e2dab3144886b27ebc8f64de1.jpg'
    '06c641c505d72f05123f5d7e3cfe7585792f207b.webp'
    '5b9e5259cb0bea507f33f2eb7c3744b0c87f3cbf.jpg'
    'ee42d7cc8bdff7936f63ae1935804c7cec0d5c9b.webp'
    '03ba97c4b54916ca1df9f59f49c0ad3b89394400.jpg'
    '6168d2f9257ae54751d45934388f5167d240e22c.jpg'
    '880ab3b4500e6e1a4728641af445d7964c6e9eb0.jpg'
    '6d014d510c57bd5222a4b361a772d8a3ca4d9e21.jpg'
    'ac4b1b0e4547c46186d6de06b9329eb2805b1a22.jpg'
    '59cf14b0c4dfd845f981d30136b365a835b0ee4d.jpg'
    'f6047914f2985a80c531da2623a0db128b07c4d0.jpg'
    'f0fd265743d4e06f72cd458df417fb24f53cf34a.jpg'
    '24e76381dbfda362612ab2bd2ab8f4d948896d7f.jpg'
    'c1beadeaf46b2db5b64f55f352e26cd61caa7d62.jpg'
    'c960b19d6be84daac5e93d89cc71bb918bee2e8c.jpg'
    '4599e5e8cf13b107ba46e82e678506d3e8ac5d12.jpg'
    '9472950fac2d9e1d47754f12377e40d3f7f80620.jpg'
    '222dc30eb7092a96e49b0b6d4d1888871e3ee3b1.jpg'
    'd7cafffb08c082044957e7ad0a51e17085e67993.jpg'
    'bd225f89f6414e454a1938a4892135a6723e6e81.jpg'
    '022a713991e2d12d80ad1a8c15a63f6b71fccbeb.jpg'
    'd300321f070107728d951588e9bdd6daf97f9812.jpg'
    'fa5fe43cb8d62b0b033976c5076ec6a7fe18a38e.jpg'
    '6cb7dc49273fcabaf181b98594434111ca6c5a62.jpg'
    'f0f327774e573546fc3b4c363c7a59e0a684dec4.jpg'
    '5b96de3e54100a99784aee4c6057a4124f3b91ac.jpg'
    '419e31136e460f392656ad8f9e6761696791e7bb.jpg'
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<main class="pd-page">')
[void]$sb.AppendLine('    <section class="pd-hero">')
[void]$sb.AppendLine('        <div class="pd-wrap">')
[void]$sb.AppendLine('            <p class="pd-eyebrow">The Pioneer Design</p>')
[void]$sb.AppendLine('            <h1 class="pd-title">Projects</h1>')
[void]$sb.AppendLine('            <p class="pd-lede">A selection of interiors, details and spaces shaped by The Pioneer Design.</p>')
[void]$sb.AppendLine('        </div>')
[void]$sb.AppendLine('    </section>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('    <section class="pd-section">')
[void]$sb.AppendLine('        <div class="pd-wrap">')
[void]$sb.AppendLine('            <div class="pd-gallery">')
$i = 0
foreach ($f in $galleryFiles) {
    [void]$sb.AppendLine("                <a class=""pd-gallery-item"" href=""assets/img/$f""><img src=""assets/img/$f"" alt=""Interior design project by The Pioneer Design"" /></a>")
    $i++
}
[void]$sb.AppendLine('            </div>')
[void]$sb.AppendLine('        </div>')
[void]$sb.AppendLine('    </section>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('    <section class="pd-cta">')
[void]$sb.AppendLine('        <div class="pd-wrap">')
[void]$sb.AppendLine('            <h2>Have a project in mind?</h2>')
[void]$sb.AppendLine('            <a class="pd-btn" href="index.html#contact">Get in touch</a>')
[void]$sb.AppendLine('        </div>')
[void]$sb.AppendLine('    </section>')
[void]$sb.AppendLine('</main>')
$projectsMain = $sb.ToString()

[IO.File]::WriteAllText((Join-Path $root 'about.html'), (New-Page 'ABOUT' $aboutMain), $utf8)
[IO.File]::WriteAllText((Join-Path $root 'projects.html'), (New-Page 'PROJECTS' $projectsMain), $utf8)

# ------------------------------------------------------------------ 404
$notFoundMain = @'
<main class="pd-page">
    <section class="pd-hero">
        <div class="pd-wrap">
            <p class="pd-eyebrow">The Pioneer Design</p>
            <h1 class="pd-title">404</h1>
            <p class="pd-lede">That page could not be found. Let&rsquo;s get you back to the work.</p>
            <p style="margin-top:32px"><a class="pd-btn pd-btn--dark" href="index.html">Back to home</a></p>
        </div>
    </section>

    <section class="pd-section">
        <div class="pd-wrap">
            <h2 class="pd-section-title">Where to next</h2>
            <ul class="pd-services">
                <li><span class="pd-num">01</span><span><a href="index.html" style="text-decoration:none;color:inherit">Home</a></span></li>
                <li><span class="pd-num">02</span><span><a href="about.html" style="text-decoration:none;color:inherit">About the studio</a></span></li>
                <li><span class="pd-num">03</span><span><a href="projects.html" style="text-decoration:none;color:inherit">Projects</a></span></li>
            </ul>
        </div>
    </section>
</main>
'@
[IO.File]::WriteAllText((Join-Path $root '404.html'), (New-Page 'PAGE NOT FOUND' $notFoundMain), $utf8)

"about.html   $([Math]::Round((Get-Item (Join-Path $root 'about.html')).Length / 1KB, 1)) KB"
"projects.html $([Math]::Round((Get-Item (Join-Path $root 'projects.html')).Length / 1KB, 1)) KB"
"404.html     $([Math]::Round((Get-Item (Join-Path $root '404.html')).Length / 1KB, 1)) KB"
