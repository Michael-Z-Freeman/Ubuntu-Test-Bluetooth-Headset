import time
import numpy as np
import sounddevice as sd
names=sd.query_devices()
i=next((i for i,d in enumerate(names) if d['name']=='Ubuntu Test Headset' and d['max_input_channels']>0),None)
if i is None: raise SystemExit('Bluetooth input absent')
rate=int(names[i]['default_samplerate']); parts=[]
def cb(data, frames, info, status):
    parts.append(data.copy())
    if len(parts)%20==0:
        print('blocks',len(parts),'peak',float(np.max(np.abs(data))),'status',str(status),flush=True)
with sd.InputStream(device=i,channels=1,samplerate=rate,blocksize=800,dtype='float32',callback=cb):
    print('Bluetooth capture started:',rate,'Hz',flush=True)
    time.sleep(65)
if parts:
    x=np.concatenate(parts)[:,0]
    np.save('/tmp/ubuntu-bt-audio.npy',x); np.save('/tmp/ubuntu-bt-rate.npy',np.array(rate))
    print('samples',len(x),'seconds',len(x)/rate,'rate',rate,'peak',float(np.max(np.abs(x))),flush=True)
else: print('No audio samples received',flush=True)
