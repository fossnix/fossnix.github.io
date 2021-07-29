;; publish.el --- Publish org-mode project on Gitlab Pages

;;; Commentary:
;; This script will convert the org-mode files in this directory into
;; html.

;;; Code:
(require 'package)
(package-initialize)
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-install 'htmlize)
(package-install 'org-plus-contrib)
(package-install 'ox-reveal)
;; Don't want to invoke insert-shebang locally
(remove-hook 'find-file-hook 'insert-shebang)

(require 'org)
(require 'ox-publish)
(require 'htmlize)
(require 'ox-html)
(require 'ox-rss)
(require 'ox-reveal)

;; setting to nil, avoids "Author: x" at the bottom
(setq org-export-with-section-numbers nil
      org-export-with-smart-quotes t
      org-export-with-toc nil)

(defvar this-date-format "%b %d, %Y")
(defvar draft-dir (expand-file-name "./public/drafts"))
(defvar tags-dir "tags/")

(setq org-html-divs '((preamble "header" "top")
                      (content "main" "content")
                      (postamble "footer" "postamble"))
      org-html-container-element "section"
      org-html-metadata-timestamp-format this-date-format
      org-html-checkbox-type 'html
      org-html-html5-fancy t
      org-html-validation-link t
      org-html-doctype "html5"
      org-html-htmlize-output-type 'css
      org-src-fontify-natively t)

(defvar me/website-html-head
  "<link rel='icon' type='image/x-icon' href='/images/favicon.jpg'/>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<link rel='stylesheet' href='https://code.cdn.mozilla.net/fonts/fira.css'>
<link rel='stylesheet' href='/css/site.css?v=2' type='text/css'/>
<link rel='stylesheet' href='/css/custom.css' type='text/css'/>
<link rel='stylesheet' href='/css/syntax-coloring.css' type='text/css'/>")

(defun me/org-html-publish-to-html (plist filename pubdir)
  "Publish an org file to HTML.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

If the org file has '#+draft: t' or '#+draft: 1', the html file will be exported in ./public/drafts/"
  (with-temp-buffer
    (insert-file-contents filename)
    (if (string-match-p "^#\\+draft:.*[t,1]" (buffer-string))
        (setq pubdir draft-dir))
    (unless (file-directory-p pubdir)
      (make-directory pubdir))
    (org-publish-org-to 'html filename
		                (concat "." (or (plist-get plist :html-extension)  org-html-extension "html"))
		                plist pubdir)))

(defun me/website-html-preamble (plist)
  "PLIST: An entry."
  (if (org-export-get-date plist this-date-format)
        (plist-put plist
             :subtitle (format "Published on %s by %s."
                               (org-export-get-date plist this-date-format)
                               (car (plist-get plist :author)))))
  ;; Preamble
  (with-temp-buffer
    (insert-file-contents "../html-templates/preamble.html") (buffer-string)))

(defun me/website-html-postamble (plist)
  "PLIST."
  (concat (format
           (with-temp-buffer
             (insert-file-contents "../html-templates/postamble.html") (buffer-string))
           (format-time-string this-date-format (plist-get plist :time)) (plist-get plist :creator))))

(defvar site-attachments
  (regexp-opt '("jpg" "jpeg" "gif" "png" "svg"
                "ico" "cur" "css" "js" "woff" "html" "pdf"))
  "File types that are published as static files.")

(defun me/org-publish-generate-tags (tags kwdir kwlinks &optional pdir)
  "Display TAGS and generate a file per tag and group entries under tag.
Extract TAGS from :filetags. The KWDIR directory will have all
file per tag with entries. KWLINKS actually has file entries in
the form of,

'([[file:../tags/tag1.org][tag1]] [[file:../tags/tag2.org][tag2]])

PDIR will be nil for PROJECT 'posts'. Refer (me/org-publish-get-pdir).
Also refer https://gitlab.com/hperrey/hoowl_blog/-/blob/master/publish.el
for another good implemenation of tags."
  (if (stringp tags)
      (progn
        (let ((tags (split-string tags)))
          (dolist (tag tags)
            (push (format "[[file:../%s][%s]]" (concat kwdir tag ".org") tag) kwlinks)
            (if (file-exists-p (concat kwdir tag ".org"))
                (with-temp-buffer
                  (insert (format "\n- [[file:../%s][%s]]" (concat pdir entry) (org-publish-find-title entry project)))
                  (append-to-file (point-min) (point-max) (concat kwdir tag ".org")))
              (progn
                (unless (file-directory-p kwdir)
                      (make-directory kwdir))
                (with-temp-file
                    (concat kwdir tag ".org")
                  (insert (format "#+TITLE: %s\n- [[file:../%s][%s]]"
                                  tag
                                  (concat pdir entry)
                                  (org-publish-find-title entry project))))))))
        kwlinks)
    nil))

(defun me/org-publish-get-pdir (pdir)
  "The PDIR is the :publishing directory.
This is required to set correct file path for entries with
projects other that 'posts', the entries in the 'post' is
published on the root(/) where as other projects has there own
namespace."
  (if (and (stringp pdir) (> (length (split-string pdir "/")) 2))
      (concat (car (last (split-string pdir "/"))) "/")
    nil))

(defun me/org-sitemap-format-entry (entry style project)
  "Format posts with author and published data in the index page.

ENTRY: file-name
STYLE:
PROJECT: posts in this case.

Build the Index with title(ENTRY), publication date and tags.
The tags are space separated values for '#+filetags:' in the PROJECT."
  (let* ((tags (car (org-publish-find-property entry :filetags project)))
         (kwdir (plist-get (cdr project) :tags-directory))
         (pdir (me/org-publish-get-pdir (plist-get (cdr project) :publishing-directory)))
         (kwlinks))
      (format "*[[file:%s][%s]]*
            #+HTML: <p class='pubdate'>by %s on %s.</p>
            Tag%s: /%s/"
            entry
            (org-publish-find-title entry project)
            (car (org-publish-find-property entry :author project))
            (format-time-string this-date-format
                                (org-publish-find-date entry project))
            (funcall (lambda (x) (if (> x 1) "s" "")) (length (split-string tags)))
            (mapconcat 'identity (me/org-publish-generate-tags tags kwdir kwlinks pdir) ", "))))

(defun me/org-sitemap-function (title list)
  "Sitemap generation function.
TITLE:
LIST."
  (org-list-to-subtree list))

(defun me/org-reveal-publish-to-html (plist filename pub-dir)
  "Publish an org file to reveal.js HTML Presentation.
FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory. Returns output file name."
  (let ((org-reveal-root "http://cdn.jsdelivr.net/reveal.js/3.0.0/"))
    (org-publish-org-to 'reveal filename ".html" plist pub-dir)))

(setq org-publish-project-alist
      `(("posts"
         :base-directory "posts"
         :base-extension "org"
         :recursive t
         :publishing-function me/org-html-publish-to-html
         :publishing-directory "./public"
         :exclude ,(regexp-opt '("README.org" "draft" "404.org"))
         :auto-sitemap t
         :sitemap-filename "index.org"
         :sitemap-title "Blog Index"
         :sitemap-format-entry me/org-sitemap-format-entry
         :sitemap-style list
         :sitemap-sort-files anti-chronologically
         :html-link-home "/"
         :html-link-up "/"
         :html-head-include-scripts t
         :html-head-include-default-style nil
         :html-head ,me/website-html-head
         :html-preamble me/website-html-preamble
         :html-postamble me/website-html-postamble
         :tags-directory ,tags-dir)
        ("tags"
         :base-directory "tags"
         :base-extension "org"
         :auto-sitemap t
         :recursive nil
         :sitemap-filename "index.org"
         :sitemap-title "Tags"
         :publishing-directory "./public/tags"
         :publishing-function org-html-publish-to-html
         :sitemap-style list
         :html-link-home "/"
         :html-link-up "/tags"
         :html-head-include-scripts t
         :html-head-include-default-style nil
         :html-head ,me/website-html-head
         :html-preamble me/website-html-preamble
         :html-postamble me/website-html-postamble)
        ("about"
         :base-directory "about"
         :base-extension "org"
         :exclude ,(regexp-opt '("README.org" "draft"))
         :index-filename "index.org"
         :recursive nil
         :publishing-function org-html-publish-to-html
         :publishing-directory "./public/about"
         :html-link-home "/"
         :html-link-up "/"
         :html-head-include-scripts t
         :html-head-include-default-style nil
         :html-head ,me/website-html-head
         :html-preamble me/website-html-preamble
         :html-postamble me/website-html-postamble)
        ("css"
         :base-directory "./css"
         :base-extension "css"
         :publishing-directory "./public/css"
         :publishing-function org-publish-attachment
         :recursive t)
        ("images"
         :base-directory "./images"
         :base-extension ,site-attachments
         :publishing-directory "./public/images"
         :publishing-function org-publish-attachment
         :recursive t)
        ("assets"
         :base-directory "./assets"
         :base-extension ,site-attachments
         :publishing-directory "./public/assets"
         :publishing-function org-publish-attachment
         :recursive t)
        ("rss"
         :base-directory "posts"
         :base-extension "org"
         :html-link-home "https://fossnix.netlify.app/"
         :rss-link-home "https://fossnix.netlify.app/index.xml"
         :html-link-use-abs-url t
         :rss-extension "xml"
         :publishing-directory "./public"
         :publishing-function (org-rss-publish-to-rss)
         :section-number t
         :exclude ".*"
         :include ("index.org")
         :table-of-contents t)
        ("all" :components ("posts" "about" "tags" "css" "images" "assets" "rss"))))

(provide 'publish)

(defun fix-rss-feed-mrf ()
  "docstr"
 (let ((case-fold-search t)) ; or nil

  (find-file "public/index.xml")
  (goto-char (point-min))
  (while (search-forward "<li>" nil t)
    (replace-match "<item>"))

  (goto-char (point-min))
  (while (search-forward "</li>" nil t)
    (replace-match "</item>"))

  (goto-char (point-min))
  (while (search-forward "<ul class=\"org-ul\">" nil t)
    (replace-match ""))

  (goto-char (point-min))
  (while (search-forward "</ul>" nil t)
    (replace-match ""))

  (goto-char (point-min))
  (while (search-forward "<b>" nil t)
    (replace-match "<title>"))
  (goto-char (point-min))
  (while (search-forward "</b>" nil t)
    (replace-match "</title>"))


  (goto-char (point-min))
  (while (search-forward "<p class='pubdate '>" nil t)
    (replace-match "<pubDate>"))
  (goto-char (point-min))
  (while (search-forward "</p></item>" nil t)
    (replace-match "</pubDate></item>"))
  
  (goto-char (point-min))
  (while (search-forward "<item><p>" nil t)
    (replace-match "<item>"))
  (goto-char (point-min))
  (while (search-forward "</p>" nil t)
    (replace-match ""))

  (goto-char (point-min))
  (while (perform-replace "\\(<title>\\)\\(<a.*\".*\">\\)" "\\2</a>\\1" nil t nil))
  (goto-char (point-min))
  (while (search-forward "</a></title>" nil t)
    (replace-match "</title>"))

  (goto-char (point-min))
  (while (search-forward "<a href=\"" nil t)
    (replace-match "<a href=\"https://themrfantastic.gitlab.io/"))

  (goto-char (point-min))
  (while (search-forward "<a href=\"" nil t)
    (replace-match "<link>"))
  (goto-char (point-min))
  (while (search-forward "\"></a>" nil t)
    (replace-match "</link>"))

  (goto-char (point-min))
  (while (perform-replace "\\(<link\\)\\(>.*<\\)\\(/link>\\)" "\\1\\2\\3<guid\\2/guid>" nil t nil))
  ;; repeat for other string pairs

  (save-buffer)
  (kill-buffer "index.xml")
  ))
;;; publish.el ends here
