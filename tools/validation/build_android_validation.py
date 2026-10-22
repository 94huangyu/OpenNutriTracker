from pathlib import Path
import subprocess,os,signal,sys,json
mode=sys.argv[1];assert mode in ['debug-probe','profile-app','release-app']
init=Path('.tools/gradle/init.d/ont-m5-r3-offline.gradle');assert not init.exists()
repo=Path('.tools/release-maven' if mode=='release-app' else '.tools/m5-maven').resolve().as_uri();init.parent.mkdir(exist_ok=True)
engine_mode='release' if mode=='release-app' else 'profile'
if mode=='release-app':
 assert Path(os.environ.get('SHIJI_SIGNING_CONFIG','missing-signing-config')).is_file(), 'Set SHIJI_SIGNING_CONFIG to private metadata, not a password'
init.write_text('''gradle.startParameter.offline = true
allprojects {
 if (rootProject.projectDir.name == 'android' && rootProject.projectDir.parentFile.name == 'OpenNutriTracker') {
  repositories { maven { url = uri('%s'); content { includeModule('io.flutter','arm64_v8a_%s'); includeModule('io.flutter','flutter_embedding_%s') } } }
 }
 configurations.configureEach { resolutionStrategy.eachDependency { details ->
  if (details.requested.group == 'androidx.test' && details.requested.name == 'runner' && details.requested.version == '1.2+') details.useVersion('1.3.0')
 } }
}
'''%(repo,engine_mode,engine_mode))
# Release must regenerate plugin registrants to exclude dev-only integration_test.
args=['flutter','build','apk',*(['--no-pub'] if mode!='release-app' else []),'--flavor','shiji' if mode=='release-app' else 'validation','--target-platform','android-arm64']
args += ['--debug','--target','tools/validation/m5_isolated_restore.dart'] if mode=='debug-probe' else ['--release'] if mode=='release-app' else ['--profile']
attempt=1
while (log:=Path(f'.tools/logs/m5-r3-build-{mode}-r{attempt}.log')).exists():attempt+=1
try:
 with log.open('w') as out:
  script='source .tools/env.sh; export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.workers.max=2"; exec '+__import__('shlex').join(args)
  p=subprocess.Popen(['/bin/bash','-c',script],stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=300)
  except subprocess.TimeoutExpired:
   os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=5)
   raise SystemExit('Timed out; own build process group stopped')
 print(json.dumps({'mode':mode,'exitCode':code,'log':str(log)}),flush=True)
 raise SystemExit(code)
finally:init.unlink(missing_ok=True)
