var Et=Object.defineProperty;var xt=Object.getOwnPropertyDescriptor;var x=(i,t,e,s)=>{for(var r=s>1?void 0:s?xt(t,e):t,o=i.length-1,n;o>=0;o--)(n=i[o])&&(r=(s?n(t,e,r):n(r))||r);return s&&r&&Et(t,e,r),r};var I=globalThis,q=I.ShadowRoot&&(I.ShadyCSS===void 0||I.ShadyCSS.nativeShadow)&&"adoptedStyleSheets"in Document.prototype&&"replace"in CSSStyleSheet.prototype,K=Symbol(),rt=new WeakMap,k=class{constructor(t,e,s){if(this._$cssResult$=!0,s!==K)throw Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");this.cssText=t,this.t=e}get styleSheet(){let t=this.o,e=this.t;if(q&&t===void 0){let s=e!==void 0&&e.length===1;s&&(t=rt.get(e)),t===void 0&&((this.o=t=new CSSStyleSheet).replaceSync(this.cssText),s&&rt.set(e,t))}return t}toString(){return this.cssText}},it=i=>new k(typeof i=="string"?i:i+"",void 0,K),m=(i,...t)=>{let e=i.length===1?i[0]:t.reduce((s,r,o)=>s+(n=>{if(n._$cssResult$===!0)return n.cssText;if(typeof n=="number")return n;throw Error("Value passed to 'css' function must be a 'css' function result: "+n+". Use 'unsafeCSS' to pass non-literal values, but take care to ensure page security.")})(r)+i[o+1],i[0]);return new k(e,i,K)},J=(i,t)=>{if(q)i.adoptedStyleSheets=t.map(e=>e instanceof CSSStyleSheet?e:e.styleSheet);else for(let e of t){let s=document.createElement("style"),r=I.litNonce;r!==void 0&&s.setAttribute("nonce",r),s.textContent=e.cssText,i.appendChild(s)}},j=q?i=>i:i=>i instanceof CSSStyleSheet?(t=>{let e="";for(let s of t.cssRules)e+=s.cssText;return it(e)})(i):i;var{is:wt,defineProperty:Ct,getOwnPropertyDescriptor:kt,getOwnPropertyNames:Pt,getOwnPropertySymbols:Ut,getPrototypeOf:Rt}=Object,B=globalThis,ot=B.trustedTypes,Nt=ot?ot.emptyScript:"",Ot=B.reactiveElementPolyfillSupport,P=(i,t)=>i,U={toAttribute(i,t){switch(t){case Boolean:i=i?Nt:null;break;case Object:case Array:i=i==null?i:JSON.stringify(i)}return i},fromAttribute(i,t){let e=i;switch(t){case Boolean:e=i!==null;break;case Number:e=i===null?null:Number(i);break;case Object:case Array:try{e=JSON.parse(i)}catch{e=null}}return e}},D=(i,t)=>!wt(i,t),nt={attribute:!0,type:String,converter:U,reflect:!1,hasChanged:D};Symbol.metadata??=Symbol("metadata"),B.litPropertyMetadata??=new WeakMap;var f=class extends HTMLElement{static addInitializer(t){this._$Ei(),(this.l??=[]).push(t)}static get observedAttributes(){return this.finalize(),this._$Eh&&[...this._$Eh.keys()]}static createProperty(t,e=nt){if(e.state&&(e.attribute=!1),this._$Ei(),this.elementProperties.set(t,e),!e.noAccessor){let s=Symbol(),r=this.getPropertyDescriptor(t,s,e);r!==void 0&&Ct(this.prototype,t,r)}}static getPropertyDescriptor(t,e,s){let{get:r,set:o}=kt(this.prototype,t)??{get(){return this[e]},set(n){this[e]=n}};return{get(){return r?.call(this)},set(n){let c=r?.call(this);o.call(this,n),this.requestUpdate(t,c,s)},configurable:!0,enumerable:!0}}static getPropertyOptions(t){return this.elementProperties.get(t)??nt}static _$Ei(){if(this.hasOwnProperty(P("elementProperties")))return;let t=Rt(this);t.finalize(),t.l!==void 0&&(this.l=[...t.l]),this.elementProperties=new Map(t.elementProperties)}static finalize(){if(this.hasOwnProperty(P("finalized")))return;if(this.finalized=!0,this._$Ei(),this.hasOwnProperty(P("properties"))){let e=this.properties,s=[...Pt(e),...Ut(e)];for(let r of s)this.createProperty(r,e[r])}let t=this[Symbol.metadata];if(t!==null){let e=litPropertyMetadata.get(t);if(e!==void 0)for(let[s,r]of e)this.elementProperties.set(s,r)}this._$Eh=new Map;for(let[e,s]of this.elementProperties){let r=this._$Eu(e,s);r!==void 0&&this._$Eh.set(r,e)}this.elementStyles=this.finalizeStyles(this.styles)}static finalizeStyles(t){let e=[];if(Array.isArray(t)){let s=new Set(t.flat(1/0).reverse());for(let r of s)e.unshift(j(r))}else t!==void 0&&e.push(j(t));return e}static _$Eu(t,e){let s=e.attribute;return s===!1?void 0:typeof s=="string"?s:typeof t=="string"?t.toLowerCase():void 0}constructor(){super(),this._$Ep=void 0,this.isUpdatePending=!1,this.hasUpdated=!1,this._$Em=null,this._$Ev()}_$Ev(){this._$Eg=new Promise(t=>this.enableUpdating=t),this._$AL=new Map,this._$ES(),this.requestUpdate(),this.constructor.l?.forEach(t=>t(this))}addController(t){(this._$E_??=new Set).add(t),this.renderRoot!==void 0&&this.isConnected&&t.hostConnected?.()}removeController(t){this._$E_?.delete(t)}_$ES(){let t=new Map,e=this.constructor.elementProperties;for(let s of e.keys())this.hasOwnProperty(s)&&(t.set(s,this[s]),delete this[s]);t.size>0&&(this._$Ep=t)}createRenderRoot(){let t=this.shadowRoot??this.attachShadow(this.constructor.shadowRootOptions);return J(t,this.constructor.elementStyles),t}connectedCallback(){this.renderRoot??=this.createRenderRoot(),this.enableUpdating(!0),this._$E_?.forEach(t=>t.hostConnected?.())}enableUpdating(t){}disconnectedCallback(){this._$E_?.forEach(t=>t.hostDisconnected?.())}attributeChangedCallback(t,e,s){this._$AK(t,s)}_$EO(t,e){let s=this.constructor.elementProperties.get(t),r=this.constructor._$Eu(t,s);if(r!==void 0&&s.reflect===!0){let o=(s.converter?.toAttribute!==void 0?s.converter:U).toAttribute(e,s.type);this._$Em=t,o==null?this.removeAttribute(r):this.setAttribute(r,o),this._$Em=null}}_$AK(t,e){let s=this.constructor,r=s._$Eh.get(t);if(r!==void 0&&this._$Em!==r){let o=s.getPropertyOptions(r),n=typeof o.converter=="function"?{fromAttribute:o.converter}:o.converter?.fromAttribute!==void 0?o.converter:U;this._$Em=r,this[r]=n.fromAttribute(e,o.type),this._$Em=null}}requestUpdate(t,e,s){if(t!==void 0){if(s??=this.constructor.getPropertyOptions(t),!(s.hasChanged??D)(this[t],e))return;this.C(t,e,s)}this.isUpdatePending===!1&&(this._$Eg=this._$EP())}C(t,e,s){this._$AL.has(t)||this._$AL.set(t,e),s.reflect===!0&&this._$Em!==t&&(this._$ET??=new Set).add(t)}async _$EP(){this.isUpdatePending=!0;try{await this._$Eg}catch(e){Promise.reject(e)}let t=this.scheduleUpdate();return t!=null&&await t,!this.isUpdatePending}scheduleUpdate(){return this.performUpdate()}performUpdate(){if(!this.isUpdatePending)return;if(!this.hasUpdated){if(this.renderRoot??=this.createRenderRoot(),this._$Ep){for(let[r,o]of this._$Ep)this[r]=o;this._$Ep=void 0}let s=this.constructor.elementProperties;if(s.size>0)for(let[r,o]of s)o.wrapped!==!0||this._$AL.has(r)||this[r]===void 0||this.C(r,this[r],o)}let t=!1,e=this._$AL;try{t=this.shouldUpdate(e),t?(this.willUpdate(e),this._$E_?.forEach(s=>s.hostUpdate?.()),this.update(e)):this._$Ej()}catch(s){throw t=!1,this._$Ej(),s}t&&this._$AE(e)}willUpdate(t){}_$AE(t){this._$E_?.forEach(e=>e.hostUpdated?.()),this.hasUpdated||(this.hasUpdated=!0,this.firstUpdated(t)),this.updated(t)}_$Ej(){this._$AL=new Map,this.isUpdatePending=!1}get updateComplete(){return this.getUpdateComplete()}getUpdateComplete(){return this._$Eg}shouldUpdate(t){return!0}update(t){this._$ET&&=this._$ET.forEach(e=>this._$EO(e,this[e])),this._$Ej()}updated(t){}firstUpdated(t){}};f.elementStyles=[],f.shadowRootOptions={mode:"open"},f[P("elementProperties")]=new Map,f[P("finalized")]=new Map,Ot?.({ReactiveElement:f}),(B.reactiveElementVersions??=[]).push("2.0.3");var tt=globalThis,W=tt.trustedTypes,at=W?W.createPolicy("lit-html",{createHTML:i=>i}):void 0,ut="$lit$",y=`lit$${(Math.random()+"").slice(9)}$`,mt="?"+y,Tt=`<${mt}>`,S=document,N=()=>S.createComment(""),O=i=>i===null||typeof i!="object"&&typeof i!="function",ft=Array.isArray,Mt=i=>ft(i)||typeof i?.[Symbol.iterator]=="function",X=`[ 	
\f\r]`,R=/<(?:(!--|\/[^a-zA-Z])|(\/?[a-zA-Z][^>\s]*)|(\/?$))/g,lt=/-->/g,ct=/>/g,v=RegExp(`>|${X}(?:([^\\s"'>=/]+)(${X}*=${X}*(?:[^ 	
\f\r"'\`<>=]|("|')|))|$)`,"g"),ht=/'/g,dt=/"/g,gt=/^(?:script|style|textarea|title)$/i,$t=i=>(t,...e)=>({_$litType$:i,strings:t,values:e}),_=$t(1),Xt=$t(2),E=Symbol.for("lit-noChange"),d=Symbol.for("lit-nothing"),pt=new WeakMap,b=S.createTreeWalker(S,129);function yt(i,t){if(!Array.isArray(i)||!i.hasOwnProperty("raw"))throw Error("invalid template strings array");return at!==void 0?at.createHTML(t):t}var Ht=(i,t)=>{let e=i.length-1,s=[],r,o=t===2?"<svg>":"",n=R;for(let c=0;c<e;c++){let a=i[c],h,p,l=-1,u=0;for(;u<a.length&&(n.lastIndex=u,p=n.exec(a),p!==null);)u=n.lastIndex,n===R?p[1]==="!--"?n=lt:p[1]!==void 0?n=ct:p[2]!==void 0?(gt.test(p[2])&&(r=RegExp("</"+p[2],"g")),n=v):p[3]!==void 0&&(n=v):n===v?p[0]===">"?(n=r??R,l=-1):p[1]===void 0?l=-2:(l=n.lastIndex-p[2].length,h=p[1],n=p[3]===void 0?v:p[3]==='"'?dt:ht):n===dt||n===ht?n=v:n===lt||n===ct?n=R:(n=v,r=void 0);let $=n===v&&i[c+1].startsWith("/>")?" ":"";o+=n===R?a+Tt:l>=0?(s.push(h),a.slice(0,l)+ut+a.slice(l)+y+$):a+y+(l===-2?c:$)}return[yt(i,o+(i[e]||"<?>")+(t===2?"</svg>":"")),s]},T=class i{constructor({strings:t,_$litType$:e},s){let r;this.parts=[];let o=0,n=0,c=t.length-1,a=this.parts,[h,p]=Ht(t,e);if(this.el=i.createElement(h,s),b.currentNode=this.el.content,e===2){let l=this.el.content.firstChild;l.replaceWith(...l.childNodes)}for(;(r=b.nextNode())!==null&&a.length<c;){if(r.nodeType===1){if(r.hasAttributes())for(let l of r.getAttributeNames())if(l.endsWith(ut)){let u=p[n++],$=r.getAttribute(l).split(y),z=/([.?@])?(.*)/.exec(u);a.push({type:1,index:o,name:z[2],strings:$,ctor:z[1]==="."?F:z[1]==="?"?G:z[1]==="@"?Q:C}),r.removeAttribute(l)}else l.startsWith(y)&&(a.push({type:6,index:o}),r.removeAttribute(l));if(gt.test(r.tagName)){let l=r.textContent.split(y),u=l.length-1;if(u>0){r.textContent=W?W.emptyScript:"";for(let $=0;$<u;$++)r.append(l[$],N()),b.nextNode(),a.push({type:2,index:++o});r.append(l[u],N())}}}else if(r.nodeType===8)if(r.data===mt)a.push({type:2,index:o});else{let l=-1;for(;(l=r.data.indexOf(y,l+1))!==-1;)a.push({type:7,index:o}),l+=y.length-1}o++}}static createElement(t,e){let s=S.createElement("template");return s.innerHTML=t,s}};function w(i,t,e=i,s){if(t===E)return t;let r=s!==void 0?e._$Co?.[s]:e._$Cl,o=O(t)?void 0:t._$litDirective$;return r?.constructor!==o&&(r?._$AO?.(!1),o===void 0?r=void 0:(r=new o(i),r._$AT(i,e,s)),s!==void 0?(e._$Co??=[])[s]=r:e._$Cl=r),r!==void 0&&(t=w(i,r._$AS(i,t.values),r,s)),t}var Z=class{constructor(t,e){this._$AV=[],this._$AN=void 0,this._$AD=t,this._$AM=e}get parentNode(){return this._$AM.parentNode}get _$AU(){return this._$AM._$AU}u(t){let{el:{content:e},parts:s}=this._$AD,r=(t?.creationScope??S).importNode(e,!0);b.currentNode=r;let o=b.nextNode(),n=0,c=0,a=s[0];for(;a!==void 0;){if(n===a.index){let h;a.type===2?h=new M(o,o.nextSibling,this,t):a.type===1?h=new a.ctor(o,a.name,a.strings,this,t):a.type===6&&(h=new Y(o,this,t)),this._$AV.push(h),a=s[++c]}n!==a?.index&&(o=b.nextNode(),n++)}return b.currentNode=S,r}p(t){let e=0;for(let s of this._$AV)s!==void 0&&(s.strings!==void 0?(s._$AI(t,s,e),e+=s.strings.length-2):s._$AI(t[e])),e++}},M=class i{get _$AU(){return this._$AM?._$AU??this._$Cv}constructor(t,e,s,r){this.type=2,this._$AH=d,this._$AN=void 0,this._$AA=t,this._$AB=e,this._$AM=s,this.options=r,this._$Cv=r?.isConnected??!0}get parentNode(){let t=this._$AA.parentNode,e=this._$AM;return e!==void 0&&t?.nodeType===11&&(t=e.parentNode),t}get startNode(){return this._$AA}get endNode(){return this._$AB}_$AI(t,e=this){t=w(this,t,e),O(t)?t===d||t==null||t===""?(this._$AH!==d&&this._$AR(),this._$AH=d):t!==this._$AH&&t!==E&&this._(t):t._$litType$!==void 0?this.g(t):t.nodeType!==void 0?this.$(t):Mt(t)?this.T(t):this._(t)}k(t){return this._$AA.parentNode.insertBefore(t,this._$AB)}$(t){this._$AH!==t&&(this._$AR(),this._$AH=this.k(t))}_(t){this._$AH!==d&&O(this._$AH)?this._$AA.nextSibling.data=t:this.$(S.createTextNode(t)),this._$AH=t}g(t){let{values:e,_$litType$:s}=t,r=typeof s=="number"?this._$AC(t):(s.el===void 0&&(s.el=T.createElement(yt(s.h,s.h[0]),this.options)),s);if(this._$AH?._$AD===r)this._$AH.p(e);else{let o=new Z(r,this),n=o.u(this.options);o.p(e),this.$(n),this._$AH=o}}_$AC(t){let e=pt.get(t.strings);return e===void 0&&pt.set(t.strings,e=new T(t)),e}T(t){ft(this._$AH)||(this._$AH=[],this._$AR());let e=this._$AH,s,r=0;for(let o of t)r===e.length?e.push(s=new i(this.k(N()),this.k(N()),this,this.options)):s=e[r],s._$AI(o),r++;r<e.length&&(this._$AR(s&&s._$AB.nextSibling,r),e.length=r)}_$AR(t=this._$AA.nextSibling,e){for(this._$AP?.(!1,!0,e);t&&t!==this._$AB;){let s=t.nextSibling;t.remove(),t=s}}setConnected(t){this._$AM===void 0&&(this._$Cv=t,this._$AP?.(t))}},C=class{get tagName(){return this.element.tagName}get _$AU(){return this._$AM._$AU}constructor(t,e,s,r,o){this.type=1,this._$AH=d,this._$AN=void 0,this.element=t,this.name=e,this._$AM=r,this.options=o,s.length>2||s[0]!==""||s[1]!==""?(this._$AH=Array(s.length-1).fill(new String),this.strings=s):this._$AH=d}_$AI(t,e=this,s,r){let o=this.strings,n=!1;if(o===void 0)t=w(this,t,e,0),n=!O(t)||t!==this._$AH&&t!==E,n&&(this._$AH=t);else{let c=t,a,h;for(t=o[0],a=0;a<o.length-1;a++)h=w(this,c[s+a],e,a),h===E&&(h=this._$AH[a]),n||=!O(h)||h!==this._$AH[a],h===d?t=d:t!==d&&(t+=(h??"")+o[a+1]),this._$AH[a]=h}n&&!r&&this.O(t)}O(t){t===d?this.element.removeAttribute(this.name):this.element.setAttribute(this.name,t??"")}},F=class extends C{constructor(){super(...arguments),this.type=3}O(t){this.element[this.name]=t===d?void 0:t}},G=class extends C{constructor(){super(...arguments),this.type=4}O(t){this.element.toggleAttribute(this.name,!!t&&t!==d)}},Q=class extends C{constructor(t,e,s,r,o){super(t,e,s,r,o),this.type=5}_$AI(t,e=this){if((t=w(this,t,e,0)??d)===E)return;let s=this._$AH,r=t===d&&s!==d||t.capture!==s.capture||t.once!==s.once||t.passive!==s.passive,o=t!==d&&(s===d||r);r&&this.element.removeEventListener(this.name,this,s),o&&this.element.addEventListener(this.name,this,t),this._$AH=t}handleEvent(t){typeof this._$AH=="function"?this._$AH.call(this.options?.host??this.element,t):this._$AH.handleEvent(t)}},Y=class{constructor(t,e,s){this.element=t,this.type=6,this._$AN=void 0,this._$AM=e,this.options=s}get _$AU(){return this._$AM._$AU}_$AI(t){w(this,t)}};var Lt=tt.litHtmlPolyfillSupport;Lt?.(T,M),(tt.litHtmlVersions??=[]).push("3.1.1");var _t=(i,t,e)=>{let s=e?.renderBefore??t,r=s._$litPart$;if(r===void 0){let o=e?.renderBefore??null;s._$litPart$=r=new M(t.insertBefore(N(),o),o,void 0,e??{})}return r._$AI(i),r};var g=class extends f{constructor(){super(...arguments),this.renderOptions={host:this},this._$Do=void 0}createRenderRoot(){let t=super.createRenderRoot();return this.renderOptions.renderBefore??=t.firstChild,t}update(t){let e=this.render();this.hasUpdated||(this.renderOptions.isConnected=this.isConnected),super.update(t),this._$Do=_t(e,this.renderRoot,this.renderOptions)}connectedCallback(){super.connectedCallback(),this._$Do?.setConnected(!0)}disconnectedCallback(){super.disconnectedCallback(),this._$Do?.setConnected(!1)}render(){return E}};g._$litElement$=!0,g["finalized"]=!0,globalThis.litElementHydrateSupport?.({LitElement:g});var zt=globalThis.litElementPolyfillSupport;zt?.({LitElement:g});(globalThis.litElementVersions??=[]).push("4.0.3");var et=i=>(t,e)=>{e!==void 0?e.addInitializer(()=>{customElements.define(i,t)}):customElements.define(i,t)};var It={attribute:!0,type:String,converter:U,reflect:!1,hasChanged:D},qt=(i=It,t,e)=>{let{kind:s,metadata:r}=e,o=globalThis.litPropertyMetadata.get(r);if(o===void 0&&globalThis.litPropertyMetadata.set(r,o=new Map),o.set(e.name,i),s==="accessor"){let{name:n}=e;return{set(c){let a=t.get.call(this);t.set.call(this,c),this.requestUpdate(n,a,i)},init(c){return c!==void 0&&this.C(n,void 0,i),c}}}if(s==="setter"){let{name:n}=e;return function(c){let a=this[n];t.call(this,c),this.requestUpdate(n,a,i)}}throw Error("Unsupported decorator location: "+s)};function H(i){return(t,e)=>typeof e=="object"?qt(i,t,e):((s,r,o)=>{let n=r.hasOwnProperty(o);return r.constructor.createProperty(o,n?{...s,wrapped:!0}:s),n?Object.getOwnPropertyDescriptor(r,o):void 0})(i,t,e)}var At=m`
svg {
    fill: var(--main-font-color, black);
    vertical-align: middle;
}

a {
    display: block;
    cursor: pointer;
    border-radius: 2px;
    text-decoration: none;
    color: var(--link-font);
    padding: 0.5em 0.75em;
    word-break: break-all;
}

ul {
       	list-style: none;
       	margin: 0;
       	padding: 0;
}

.material-symbols-outlined { vertical-align: middle; font-size: 1rem }

#l-drawer {
    overflow: auto;
    contain: strict;
    position: fixed; top: 0; left: 0;
    z-index: 80;
    width: 320px; max-width: 50%;
    height: 100%;
    padding: 3rem 1.5rem;
    background: var(--float-ui-bg, #eee);
    transition: all 0.3s ease-in-out 0s;
    transform: translateX(-100%);
}
#drawer-trigger:checked ~ #l-drawer {
  transform: translateX(0);
  box-shadow: 6px 0 25px rgba(0, 0, 0, 0.16);
}
#l-drawer-close {
  display: none;
  position: fixed; top: 0; left: 0;
  z-index: 79;
  width: 100%; height: 100%;
  background: #000;
  opacity: 0;
  transition: all 0.3s ease-in-out 0s;
}
#drawer-trigger:checked ~ #l-drawer-close {
  display: block;
  opacity: 0.3;
}

#drawer-trigger { display: none }

.has-m { margin: .75rem }
.has-mw { margin-left: .75rem; margin-right: .75rem }
.has-mv { margin-top: .75rem; margin-bottom: .75rem }

md-ripple:not(:defined) {
    display: none;
}
`;var vt=m`
.section{padding:3rem 1.5rem}.section+desktop{padding:3rem 3rem}.section+desktop.is-medium{padding:9rem 4.5rem}.section+desktop.is-large{padding:18rem 6rem}
`;var st=m`
.menu{font-size:1rem}.menu-list{line-height:1.25}.menu-list a{border-radius:2px;color:var(--fgColor-default, var(--color-fg-default, hsl(0, 0%, 29%)));padding:.5em .75em;display:flex;align-items:center}.menu-list a:hover{background-color:false;color:var(--fgColor-default, var(--color-fg-default, hsl(0, 0%, 21%)))}.menu-list a.is-active{background-color:false;color:var(--fgColor-onEmphasis, var(--color-fg-on-emphasis, #fff))}.menu-list li{position:relative}.menu-list li ul{border-left:1px solid;margin:.75em;padding-left:.75em}.menu-label{color:var(--fgColor-muted, var(--color-fg-muted, hsl(0, 0%, 48%)));font-size:.75em;letter-spacing:.1em;margin-top:1em}.menu-label:not(:last-child){margin-bottom:1em}
`;var bt=(i,t={})=>_`
    <div class="menu-label">${i||"INDEX"}</div>
  `,jt=(i,t,e={})=>{let s=e.icon?_`<i class="material-symbols-outlined">${e.icon}</i>`:"";return _`
    <li><a href="${t}">${s} ${i}</a><md-ripple></md-ripple></li>
  `},St=i=>_`
    <ul class="menu-list">
      ${i.map(t=>jt(...t))}
    </ul>
    `,Bt=(i,t)=>i[0][1]?[bt(t),St(i)]:i.map(e=>{if(Array.isArray(e[0]))return St(e);let s=e.length>2?e[2]:{};return bt(e[0],s)}),A=class extends g{constructor(){super(...arguments);this.theme=!1}connectedCallback(){this.items||=window.menu_item||'[["Top", "/", { "icon": "home" }]]',super.connectedCallback()}render(){let e=Array.isArray(this.items)?this.items:JSON.parse(this.items);return _`
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200&display=block" />
  <span>
  <input id="drawer-trigger" type="checkbox" />
  <label for="drawer-trigger" style="cursor: pointer"><slot>
  <i class="material-symbols-outlined" style="font-size:24px; color: #eee">menu</i>
  </slot></label>
  <label id="l-drawer-close" for="drawer-trigger"></label>
  <aside id="l-drawer">
    <section class="section">
      <nav class="menu">
        ${Bt(e,this.title)}
      </nav>
      <slot name="south"></slot>
      ${this.theme?_`<theme-switch></theme-switch`:null}
    </section>
  </aside></span>
  `}};A.styles=[vt,st,At],x([H()],A.prototype,"title",2),x([H()],A.prototype,"items",2),x([H({type:Boolean})],A.prototype,"theme",2),A=x([et("cm-drawer")],A);var L=class extends g{render(){let t=localStorage.getItem("theme");return _`
    <div class="menu-label">Theme</div>
    <ul class="menu-list"><li style="padding: .5em 0.75em">
    <md-checkbox id="auto"
      ?checked=${t=="1"}
      class=${t=="1"?"checked":""}
      @change=${e=>{let s=document.querySelector("html").dataset;e.target.checked?(e.target.classList.add("checked"),s.colorMode="auto",localStorage.setItem("theme",1)):(e.target.classList.remove("checked"),s.colorMode="light",localStorage.setItem("theme",0),e.target.parentNode.querySelector("md-radio#light").checked=!0)}}
    ></md-checkbox><label for="auto"> auto</label>
    <div id="manual"
      style="padding: .75em 0"
      @change=${e=>{let s=document.querySelector("html").dataset;e.target.value=="light"?(s.colorMode="light",localStorage.setItem("theme",0)):(s.colorMode="dark",localStorage.setItem("theme",2))}}
    >
    <label><md-radio id="light"
      ?checked=${!["2"].includes(t)}
      name="manual" value="light"></md-radio> light</label>
    <label style="padding: 0 .5em"><md-radio
      ?checked=${t=="2"}
      name="manual" value="dark"></md-radio> dark</label>
    </div>
    </li></ul>
  `}};L.styles=[st,m`
      md-checkbox.checked ~ #manual { display: none; }
      ul { list-style: none; padding: 0 }
    `],L=x([et("theme-switch")],L);
/*! Bundled license information:

@lit/reactive-element/css-tag.js:
  (**
   * @license
   * Copyright 2019 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/reactive-element.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

lit-html/lit-html.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

lit-element/lit-element.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

lit-html/is-server.js:
  (**
   * @license
   * Copyright 2022 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/custom-element.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/property.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/state.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/event-options.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/base.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/query.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/query-all.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/query-async.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/query-assigned-elements.js:
  (**
   * @license
   * Copyright 2021 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)

@lit/reactive-element/decorators/query-assigned-nodes.js:
  (**
   * @license
   * Copyright 2017 Google LLC
   * SPDX-License-Identifier: BSD-3-Clause
   *)
*/
//# sourceMappingURL=cm.js.map
