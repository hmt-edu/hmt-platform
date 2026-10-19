import html,json,collections
e=html.escape
HEAD='''<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<title>%(t)s</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/hmt/handoff/hmt-tokens.css">
<link rel="stylesheet" href="ds/hmt/components/bundle.css">
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@600;700&amp;family=Inter:wght@400;500;600;700&amp;display=swap&amp;subset=vietnamese">
<style>
body{margin:0;font-family:var(--font-ui);background:var(--bg-page);color:var(--text-primary)}
.t td,.t th{white-space:normal;vertical-align:top;height:auto;padding:6px 10px;font-size:12px;line-height:1.45}.t th{height:28px;white-space:nowrap}
h2.s{font-family:var(--font-heading);font-size:15px;margin:16px 0 6px}
.li{font-size:12.5px;line-height:1.55;margin:0 0 5px;padding-left:14px;text-indent:-14px}
</style>
</helmet>
%(body)s
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":%(w)d,"height":%(h)d}}'>
class Component extends DCLogic {
  renderVals() { return { yes: true }; }
}
</script>
</body>
</html>
'''
def frame(title,w,h,inner):
    body='<div style="width:%dpx;height:%dpx;box-sizing:border-box;background:var(--bg-page);overflow:hidden;position:relative">%s</div>'%(w,h,inner)
    return HEAD%dict(t=e(title),body=body,w=w,h=h)
TAG={'ok':'hmt-tag hmt-tag-success','wait':'hmt-tag hmt-tag-warning','froze':'hmt-tag hmt-tag-info','work':'hmt-tag hmt-tag-brand','none':'hmt-tag'}
def tag(kind,text): return '<span class="%s">%s</span>'%(TAG[kind],e(text))
def title_frame(name,count_txt,kind,status,note=''):
    inner=('<div style="position:absolute;left:0;top:0;bottom:0;width:14px;background:var(--brand-500)"></div>'
      '<div style="padding:62px 56px"><h1 style="font-family:var(--font-heading);font-size:40px;margin:0 0 14px">%s</h1>'
      '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap">%s%s<span style="font-size:15px;color:var(--text-secondary)">%s</span></div></div>')%(e(name),tag('none',count_txt),tag(kind,status),e(note))
    return frame('Nhóm · '+name,1440,220,inner)
def sub_frame(name,count_txt,note=''):
    inner=('<div style="position:absolute;left:0;top:0;bottom:0;width:10px;background:var(--brand-300)"></div>'
      '<div style="padding:24px 48px;display:flex;align-items:center;gap:14px;flex-wrap:wrap"><h2 style="font-family:var(--font-heading);font-size:28px;margin:0">%s</h2>%s<span style="font-size:14px;color:var(--text-secondary)">%s</span></div>')%(e(name),tag('none',count_txt),e(note))
    return frame('Nhóm con · '+name,1440,140,inner)
