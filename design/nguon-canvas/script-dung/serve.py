import http.server,sys,os
class H(http.server.SimpleHTTPRequestHandler):
    def guess_type(self,p):
        if '/_blob/' in p: return 'image/svg+xml'
        return super().guess_type(p)
    def log_message(self,*a): pass
os.chdir(sys.argv[1]); http.server.ThreadingHTTPServer(('127.0.0.1',8765),H).serve_forever()
