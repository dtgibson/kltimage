import subprocess,os,json,sys
exe='/Users/developer/.npm/_npx/99336612077b7094/node_modules/xcodebuildmcp/bundled/axe'
env=os.environ|{'DEVELOPER_DIR':'/Applications/Xcode.app/Contents/Developer','DYLD_FRAMEWORK_PATH':os.path.dirname(exe)+'/Frameworks'}
p=subprocess.run([exe]+sys.argv[1:],env=env,capture_output=True,text=True)
if sys.argv[1]=='describe-ui' and p.returncode==0:
 d=json.loads(p.stdout)
 def out(x):
  if isinstance(x,list):
   for a in x:out(a)
  elif isinstance(x,dict):
   if x.get('AXLabel') or x.get('AXValue'): print(json.dumps({k:x.get(k) for k in ['AXLabel','AXValue','AXUniqueId','type','enabled','frame']}))
   out(x.get('children',[]))
 out(d)
else: print(p.stdout,p.stderr)
sys.exit(p.returncode)
