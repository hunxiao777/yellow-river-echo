import * as THREE from './vendor/three.module.js';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {OrbitControls} from './vendor/OrbitControls.js';
let cleanup=()=>{};
export function mount(){cleanup();const host=document.querySelector('#three');if(!host)return;
const scene=new THREE.Scene();scene.background=new THREE.Color('#eee0c7');const camera=new THREE.PerspectiveCamera(40,host.clientWidth/host.clientHeight,.01,100);
const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setSize(host.clientWidth,host.clientHeight);host.append(renderer.domElement);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.autoRotate=true;controls.autoRotateSpeed=.7;controls.minDistance=.6;controls.maxDistance=6;
scene.add(new THREE.HemisphereLight(0xffffff,0x7c6045,3));let light=new THREE.DirectionalLight(0xffffff,3);light.position.set(2,3,4);scene.add(light);
let alive=true,id;const observer=new ResizeObserver(()=>{if(!host.isConnected)return;camera.aspect=host.clientWidth/host.clientHeight;camera.updateProjectionMatrix();renderer.setSize(host.clientWidth,host.clientHeight)});observer.observe(host);
new GLTFLoader().load('vase.glb',g=>{if(!alive)return;let box=new THREE.Box3().setFromObject(g.scene);let size=box.getSize(new THREE.Vector3());let center=box.getCenter(new THREE.Vector3());let k=2/Math.max(size.x,size.y,size.z);g.scene.position.copy(center).multiplyScalar(-k);g.scene.scale.setScalar(k);scene.add(g.scene);camera.position.set(0,.3,3.6);controls.target.set(0,0,0);controls.update();controls.saveState();document.querySelector('#modelStatus').textContent='拖动旋转 · 双指缩放 · 离线可用'},undefined,err=>{if(alive)document.querySelector('#modelStatus').textContent='模型加载失败：'+err.message});
window.resetModel=()=>controls.reset();window.toggleRotate=()=>controls.autoRotate=!controls.autoRotate;
function frame(){if(!host.isConnected){cleanup();return}id=requestAnimationFrame(frame);controls.update();renderer.render(scene,camera)}frame();
cleanup=()=>{alive=false;cancelAnimationFrame(id);observer.disconnect();controls.dispose();scene.traverse(o=>{o.geometry?.dispose();if(o.material){for(let m of [].concat(o.material)){for(let v of Object.values(m))if(v?.isTexture)v.dispose();m.dispose()}}});renderer.dispose()};}
