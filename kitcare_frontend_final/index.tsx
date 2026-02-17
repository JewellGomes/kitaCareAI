
import React, { useState, useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import { 
  Heart, 
  Map as MapIcon, 
  LayoutDashboard, 
  MessageSquare, 
  AlertCircle, 
  CheckCircle2, 
  TrendingUp,
  Search,
  Zap,
  ShieldCheck,
  Menu,
  X,
  Send,
  Receipt,
  User,
  Building2,
  ArrowRight,
  LogOut,
  Image as ImageIcon,
  History,
  Loader2,
  Filter,
  Navigation,
  Info,
  Plus,
  ShieldAlert,
  BarChart3,
  FileCheck,
  CreditCard,
  Wallet,
  ArrowUpRight,
  Settings,
  Banknote,
  Lock,
  Trash2,
  Download,
  Award,
  Package,
  Book,
  Shirt,
  ShoppingBag,
  Stethoscope,
  CloudLightning,
  Truck,
  QrCode,
  MapPin,
  ChevronLeft,
  FileText
} from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

// ==========================================
// 1. CONFIG & DATA (Malaysia Specific)
// ==========================================
const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

const ITEM_CATEGORIES = [
  { id: 'edu', name: 'Education', icon: <Book />, items: ['Books', 'Stationery', 'School Bags'], demand: 'Medium' },
  { id: 'clo', name: 'Clothing', icon: <Shirt />, items: ['Children Clothes', 'Adult Basics', 'Raincoats'], demand: 'High' },
  { id: 'foo', name: 'Food', icon: <ShoppingBag />, items: ['Dry Food (Rice/Flour)', 'Baby Formula', 'Canned Goods'], demand: 'Critical' },
  { id: 'med', name: 'Medical', icon: <Stethoscope />, items: ['First-Aid Kits', 'Sanitary Pads', 'Adult Diapers'], demand: 'High' },
  { id: 'dis', name: 'Disaster Relief', icon: <CloudLightning />, items: ['Blankets', 'Emergency Tents', 'Flashlights'], demand: 'Medium' },
];

/**
 * [BACKEND]: MOCK DATA
 * Replace INITIAL_DONATIONS with a fetch from the donation management service.
 */
const INITIAL_DONATIONS = [
  { 
    id: "KC-88421", 
    donor: "Ahmad", 
    amount: 150, 
    type: 'money',
    target: "Kelantan Flood Relief",
    ngo: "MERCY Malaysia",
    status: "In Transit",
    date: "2024-10-24",
    category: "Flood Relief",
    milestones: [
      { label: "Donation Received", date: "2024-10-24 09:00", done: true },
      { label: "Items Procured", date: "2024-10-25 14:30", done: true, detail: "10kg Rice, 2x Hygiene Kits" },
      { label: "Lorry Dispatched", date: "2024-10-26 08:00", done: true, detail: "Plate No: VAB 4421" },
      { label: "Distribution at Site", date: "Est. Oct 27", done: false, detail: "Rantau Panjang Primary School" }
    ],
    evidence: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&q=80&w=400"
  },
  {
    id: "KC-ITEM-001",
    donor: "Ahmad",
    amount: 0,
    type: 'item',
    itemDetails: "10x Secondary School Books",
    target: "Keningau Learning Center",
    ngo: "PERTIWI",
    status: "Received",
    date: "2024-10-28",
    category: "Education",
    milestones: [],
    evidence: "https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&q=80&w=400"
  }
];

/**
 * [BACKEND]: MOCK DATA
 * Replace MOCK_NEEDS with a fetch from the crisis tracking / NGO submissions service.
 */
const MOCK_NEEDS = [
  {
    id: 1,
    location: "Rantau Panjang, Kelantan",
    category: "Flood Relief",
    score: 92,
    description: "Rising water levels. Immediate need for clean water and sanitary kits for 200 displaced families.",
    verifiedBy: "MERCY Malaysia",
    coordinates: "6.0028, 101.9750",
    bank: { name: "Maybank", account: "5140-XXXX-2241", holder: "MERCY Malaysia Relief Fund" },
    physicalNeeds: ['Rice', 'Blankets', 'Hygiene Kits']
  },
  {
    id: 2,
    location: "Baling, Kedah",
    category: "Food Security",
    score: 78,
    description: "Flash flood recovery. 50 households requiring dry food rations and school supplies.",
    verifiedBy: "MyCARE",
    coordinates: "5.6766, 100.9167",
    bank: { name: "CIMB Bank", account: "8008-XXXX-9912", holder: "MyCARE Humanitarian Fund" },
    physicalNeeds: ['School Bags', 'Stationery']
  },
  {
    id: 3,
    location: "Keningau, Sabah",
    category: "Medical Aid",
    score: 65,
    description: "Remote community clinics requiring essential medicine and cooling storage for vaccines.",
    verifiedBy: "PERTIWI",
    coordinates: "5.3333, 116.1667",
    bank: { name: "Public Bank", account: "3211-XXXX-4451", holder: "PERTIWI Soup Kitchen" },
    physicalNeeds: ['First-Aid Kits', 'Thermometers']
  }
];

/**
 * [BACKEND]: MOCK DATA
 * Replace DROP_OFF_POINTS with a location/logistics database query.
 */
const DROP_OFF_POINTS = [
  { id: 1, name: "MERCY Malaysia HQ", address: "Kuala Lumpur City Centre", hours: "9AM - 5PM", condition: "New/Gently Used" },
  { id: 2, name: "St. John Ambulance Point", address: "Petaling Jaya, Selangor", hours: "8AM - 8PM", condition: "New Only" },
  { id: 3, name: "Community Library", address: "Keningau Town, Sabah", hours: "10AM - 6PM", condition: "Books/Stationery" }
];

// ==========================================
// 2. MODALS
// ==========================================

const ItemRequestModal = ({ onCancel, onComplete }: { onCancel: () => void, onComplete: (item: any) => void }) => {
  const [category, setCategory] = useState('');
  const [item, setItem] = useState('');
  const [quantity, setQuantity] = useState('');
  const [urgency, setUrgency] = useState('High');
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    /**
     * [BACKEND]: API INTERVENTION
     * Replace setTimeout with POST /api/ngo/item-requests
     */
    setTimeout(() => {
      setLoading(false);
      onComplete({ category, item, quantity, urgency });
    }, 1500);
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[70] flex items-center justify-center p-6">
      <div className="bg-white w-full max-w-md rounded-3xl overflow-hidden shadow-2xl animate-in zoom-in-95">
        <div className="p-6 bg-blue-600 text-white flex justify-between items-center">
          <div>
            <h2 className="font-bold">Request Physical Goods</h2>
            <p className="text-[10px] opacity-80 uppercase font-bold tracking-widest">Post to Donor Map</p>
          </div>
          <button onClick={onCancel} className="p-2 hover:bg-white/10 rounded-lg"><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Category</label>
            <select required value={category} onChange={e => setCategory(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-3 rounded-xl outline-none text-sm">
              <option value="">Select Category</option>
              {ITEM_CATEGORIES.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
            </select>
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Specific Item</label>
            <input required type="text" placeholder="e.g. 10kg Rice Bags" value={item} onChange={e => setItem(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-3 rounded-xl outline-none text-sm" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Quantity Needed</label>
              <input required type="number" placeholder="0" value={quantity} onChange={e => setQuantity(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-3 rounded-xl outline-none text-sm" />
            </div>
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Urgency</label>
              <select required value={urgency} onChange={e => setUrgency(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-3 rounded-xl outline-none text-sm font-bold">
                <option value="Critical">Critical</option>
                <option value="High">High</option>
                <option value="Medium">Medium</option>
              </select>
            </div>
          </div>
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white py-4 rounded-2xl font-bold shadow-lg flex items-center justify-center gap-2">
            {loading ? <Loader2 className="animate-spin" /> : <>Publish Item Request <ArrowRight size={18}/></>}
          </button>
        </form>
      </div>
    </div>
  );
};

const FieldReportModal = ({ onCancel, onComplete }: { onCancel: () => void, onComplete: (report: any) => void }) => {
  const [location, setLocation] = useState('');
  const [urgency, setUrgency] = useState('High');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    /**
     * [BACKEND]: API INTERVENTION
     * Replace setTimeout with POST /api/ngo/field-reports
     */
    setTimeout(() => {
      setLoading(false);
      onComplete({ location, urgency, description });
    }, 1500);
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[70] flex items-center justify-center p-6">
      <div className="bg-white w-full max-w-md rounded-3xl overflow-hidden shadow-2xl animate-in zoom-in-95">
        <div className="p-6 bg-blue-600 text-white flex justify-between items-center">
          <div>
            <h2 className="font-bold">New Field Report</h2>
            <p className="text-[10px] opacity-80 uppercase font-bold tracking-widest">Operational Intelligence</p>
          </div>
          <button onClick={onCancel} className="p-2 hover:bg-white/10 rounded-lg"><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Zone / Area Name</label>
            <div className="relative">
              <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input required type="text" placeholder="e.g. Kuala Krai, Kelantan" value={location} onChange={e => setLocation(e.target.value)} className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 transition-all text-sm" />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Urgency Score</label>
            <div className="flex gap-2">
              {['Medium', 'High', 'Critical'].map(level => (
                <button key={level} type="button" onClick={() => setUrgency(level)} className={`flex-1 py-2 rounded-xl text-[10px] font-bold border transition-all ${urgency === level ? 'bg-blue-600 border-blue-600 text-white shadow-md' : 'bg-slate-50 border-slate-100 text-slate-400'}`}>{level}</button>
              ))}
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Field Summary</label>
            <textarea required rows={4} placeholder="Describe the current situation, rising water levels, number of families affected..." value={description} onChange={e => setDescription(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-4 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 transition-all text-sm resize-none"></textarea>
          </div>
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white py-4 rounded-2xl font-bold shadow-lg flex items-center justify-center gap-2">
            {loading ? <Loader2 className="animate-spin" /> : <>Publish Official Report <ArrowRight size={18}/></>}
          </button>
        </form>
      </div>
    </div>
  );
};

const DonationModal = ({ need, savedMethods, role, onCancel, onComplete }: { need: any, savedMethods: any[], role: string, onCancel: () => void, onComplete: () => void }) => {
  const [donateType, setDonateType] = useState<'money' | 'item' | null>(null);
  const [amount, setAmount] = useState('50');
  const [itemCategory, setItemCategory] = useState<any>(null);
  const [selectedItem, setSelectedItem] = useState('');
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [aiMatch, setAiMatch] = useState<any>(null);

  const processMoney = () => {
    setLoading(true);
    /**
     * [BACKEND]: API INTERVENTION
     * Integrate with payment gateway (Stripe/Billplz) and update donation history.
     */
    setTimeout(() => { setLoading(false); onComplete(); }, 1500);
  };

  const processItems = () => {
    setLoading(true);
    /**
     * [BACKEND]: API INTERVENTION
     * Replace simulated logic with AI Matching service call.
     */
    setTimeout(() => {
      setAiMatch({
        community: need.location,
        ngo: need.verifiedBy,
        priority: need.score > 80 ? 'Critical' : 'Moderate',
        dropOff: DROP_OFF_POINTS[Math.floor(Math.random() * DROP_OFF_POINTS.length)]
      });
      setLoading(false);
      setStep(4);
    }, 1200);
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[60] flex items-center justify-center p-6">
      <div className="bg-white w-full max-w-md rounded-3xl overflow-hidden shadow-2xl animate-in zoom-in-95">
        <div className="p-6 bg-emerald-600 text-white flex justify-between items-center">
          <div>
            <h2 className="font-bold">Contribute to {need.location}</h2>
            <p className="text-[10px] opacity-80 uppercase font-bold tracking-widest">{need.verifiedBy}</p>
          </div>
          <button onClick={onCancel} className="p-2 hover:bg-white/10 rounded-lg"><X size={20} /></button>
        </div>

        <div className="p-6 space-y-6">
          {!donateType && (
            <div className="grid grid-cols-1 gap-4 animate-in slide-in-from-bottom-4">
              <button onClick={() => setDonateType('money')} className="p-6 bg-slate-50 border-2 border-slate-100 rounded-2xl hover:border-emerald-500 hover:bg-emerald-50 transition-all text-left group">
                <div className="bg-emerald-100 text-emerald-600 w-10 h-10 rounded-xl flex items-center justify-center mb-4 group-hover:bg-emerald-600 group-hover:text-white transition"><Banknote size={20} /></div>
                <p className="font-bold text-slate-800">Donate Money</p>
                <p className="text-xs text-slate-500">Secured transaction via KitaCare Wallet.</p>
              </button>
              <button onClick={() => setDonateType('item')} className="p-6 bg-slate-50 border-2 border-slate-100 rounded-2xl hover:border-blue-500 hover:bg-blue-50 transition-all text-left group">
                <div className="bg-blue-100 text-blue-600 w-10 h-10 rounded-xl flex items-center justify-center mb-4 group-hover:bg-blue-600 group-hover:text-white transition"><Package size={20} /></div>
                <p className="font-bold text-slate-800">Donate Items</p>
                <p className="text-xs text-slate-500">Contribute physical goods (Books, Food, etc.)</p>
              </button>
            </div>
          )}

          {donateType === 'money' && (
            <div className="space-y-4 animate-in fade-in">
              {step === 1 ? (
                <>
                  <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100 mb-2">
                    <p className="text-[10px] font-bold text-slate-400 uppercase mb-2 tracking-widest">Target Bank</p>
                    <p className="text-sm font-bold text-slate-800">{need.bank.name} - {need.bank.account}</p>
                  </div>
                  <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} className="w-full bg-slate-50 border border-slate-200 p-4 rounded-xl text-center text-xl font-bold outline-none focus:ring-2 focus:ring-emerald-500" />
                  <button onClick={() => setStep(2)} className="w-full bg-emerald-600 text-white py-4 rounded-xl font-bold">Select Wallet <ArrowRight className="inline ml-2" size={18}/></button>
                </>
              ) : (
                <>
                  <p className="text-xs font-bold text-slate-400 uppercase">Confirm Secure Payment</p>
                  <button onClick={processMoney} disabled={loading} className="w-full bg-emerald-600 text-white py-4 rounded-xl font-bold shadow-lg flex items-center justify-center gap-2">
                    {loading ? <Loader2 className="animate-spin" /> : <>Pay RM {amount} Secured <Lock size={18}/></>}
                  </button>
                </>
              )}
            </div>
          )}

          {donateType === 'item' && (
            <div className="space-y-4 animate-in fade-in">
              {step === 1 && (
                <div className="grid grid-cols-2 gap-2">
                  {ITEM_CATEGORIES.map(cat => (
                    <button key={cat.id} onClick={() => { setItemCategory(cat); setStep(2); }} className="p-3 bg-slate-50 border border-slate-100 rounded-xl flex flex-col items-center gap-2 hover:border-emerald-500 transition">
                      <div className="text-emerald-600">{cat.icon}</div>
                      <span className="text-[10px] font-bold text-slate-800">{cat.name}</span>
                      <span className={`text-[8px] font-bold px-1.5 py-0.5 rounded-full ${cat.demand === 'Critical' ? 'bg-red-50 text-red-600' : 'bg-emerald-50 text-emerald-600'}`}>{cat.demand}</span>
                    </button>
                  ))}
                </div>
              )}
              {step === 2 && (
                <div className="space-y-4">
                  <p className="text-xs font-bold text-slate-400 uppercase tracking-widest">Select Item in {itemCategory.name}</p>
                  <div className="space-y-2">
                    {itemCategory.items.map(i => (
                      <button key={i} onClick={() => setSelectedItem(i)} className={`w-full text-left p-3 rounded-xl border text-sm font-medium transition ${selectedItem === i ? 'bg-emerald-50 border-emerald-500 text-emerald-700' : 'bg-slate-50 border-slate-100 text-slate-600'}`}>{i}</button>
                    ))}
                  </div>
                  <button onClick={() => setStep(3)} disabled={!selectedItem} className="w-full bg-emerald-600 text-white py-4 rounded-xl font-bold shadow-lg disabled:opacity-50">Match with NGO <Zap className="inline ml-2" size={18}/></button>
                </div>
              )}
              {step === 3 && (
                <div className="flex flex-col items-center justify-center py-10 space-y-4">
                  <Loader2 className="w-10 h-10 animate-spin text-emerald-600" />
                  <p className="text-sm font-bold text-slate-800 animate-pulse">AI is finding local needs...</p>
                  <button onClick={processItems} className="text-xs text-emerald-600 font-bold hover:underline">Click to simulate match</button>
                </div>
              )}
              {step === 4 && (
                <div className="space-y-4 animate-in zoom-in-95">
                  <div className="p-4 bg-emerald-50 rounded-2xl border border-emerald-100">
                    <div className="flex items-start gap-3 mb-3">
                      <Zap className="text-emerald-600 flex-shrink-0" size={20} />
                      <p className="text-xs text-emerald-800 leading-relaxed"><span className="font-bold">AI Match Found!</span> Your contribution for <span className="font-bold">{selectedItem}</span> is critical for the <span className="font-bold">{aiMatch.community}</span> zone.</p>
                    </div>
                  </div>
                  <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-3">
                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Recommended Drop-off</p>
                    <div className="flex items-center gap-3">
                      <MapPin className="text-blue-600" size={18} />
                      <div>
                        <p className="text-sm font-bold text-slate-800">{aiMatch.dropOff.name}</p>
                        <p className="text-[10px] text-slate-500">{aiMatch.dropOff.address}</p>
                      </div>
                    </div>
                    <div className="flex gap-4 pt-2 text-[10px]">
                      <span className="text-slate-500"><span className="font-bold">Hours:</span> {aiMatch.dropOff.hours}</span>
                      <span className="text-slate-500"><span className="font-bold">Condition:</span> {aiMatch.dropOff.condition}</span>
                    </div>
                  </div>
                  <button onClick={onComplete} className="w-full bg-emerald-600 text-white py-4 rounded-xl font-bold shadow-lg flex items-center justify-center gap-2">Confirm & Get QR <QrCode size={18}/></button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// ==========================================
// 4. ROLE VIEWS
// ==========================================
const DonorDashboard = ({ donations, savedMethods, onAddMethod, onDeleteMethod }: { donations: any[], savedMethods: any[], onAddMethod: (m: any) => void, onDeleteMethod: (id: string) => void }) => {
  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <header className="flex flex-col md:flex-row justify-between md:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Hello, Ahmad</h1>
          <p className="text-slate-500 text-sm">Empowering Malaysian communities through KitaCare AI.</p>
        </div>
        <div className="flex gap-3">
          <div className="bg-white px-4 py-2 rounded-2xl border border-slate-100 shadow-sm">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Impact Value</p>
            <p className="text-lg font-bold text-emerald-600">RM 400.00</p>
          </div>
          <div className="bg-white px-4 py-2 rounded-2xl border border-slate-100 shadow-sm">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Lives Touched</p>
            <p className="text-lg font-bold text-blue-600">~120</p>
          </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <h2 className="font-bold text-slate-800 flex items-center gap-2"><History size={18} className="text-emerald-600" /> Active Tracking</h2>
          {donations.map(donation => (
            <div key={donation.id} className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden group">
              <div className="p-6 border-b border-slate-50 flex justify-between items-center bg-slate-50/30">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-lg ${donation.type === 'money' ? 'bg-emerald-100 text-emerald-600' : 'bg-blue-100 text-blue-600'}`}>
                    {donation.type === 'money' ? <Banknote size={16}/> : <Package size={16}/>}
                  </div>
                  <div>
                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{donation.id}</p>
                    <h3 className="font-bold text-slate-800">{donation.target}</h3>
                  </div>
                </div>
                <p className="text-xs font-bold text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full">{donation.status}</p>
              </div>
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-8">
                <div className="space-y-4">
                  {donation.type === 'item' ? (
                    <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100">
                      <p className="text-[10px] font-bold text-slate-400 uppercase mb-2">Item Summary</p>
                      <p className="text-sm font-bold text-slate-800">{donation.itemDetails}</p>
                      <p className="text-xs text-slate-500 mt-2 italic">Verified by {donation.ngo}</p>
                    </div>
                  ) : (
                    donation.milestones.map((m: any, idx: number) => (
                      <div key={idx} className="flex gap-4 relative">
                        {idx !== donation.milestones.length - 1 && (
                          <div className={`absolute left-2.5 top-6 w-0.5 h-8 ${m.done ? 'bg-emerald-500' : 'bg-slate-100'}`}></div>
                        )}
                        <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 z-10 bg-white ${m.done ? 'border-emerald-500 text-emerald-500' : 'border-slate-200 text-slate-200'}`}>
                          {m.done && <CheckCircle2 size={10} />}
                        </div>
                        <div>
                          <p className={`text-xs font-bold ${m.done ? 'text-slate-800' : 'text-slate-400'}`}>{m.label}</p>
                          <p className="text-[10px] text-slate-400">{m.date}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
                <div className="relative overflow-hidden rounded-2xl">
                  <img src={donation.evidence} alt="Aid Evidence" className="w-full h-40 object-cover shadow-inner transition-transform group-hover:scale-105" />
                  {donation.type === 'item' && <div className="absolute top-2 right-2 bg-white/90 backdrop-blur p-2 rounded-lg shadow-sm"><QrCode size={20} className="text-slate-800"/></div>}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="space-y-6">
           <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
              <h3 className="font-bold text-slate-800 flex items-center gap-2 mb-4"><Wallet size={18} className="text-emerald-600" /> KitaCare Wallet</h3>
              <div className="space-y-3">
                {savedMethods.map(method => (
                  <div key={method.id} className="p-3 bg-slate-50 border border-slate-100 rounded-xl flex items-center justify-between group">
                     <div className="flex items-center gap-3">
                       <Banknote size={16} className="text-slate-400" />
                       <p className="text-xs font-bold text-slate-800">{method.bank}</p>
                     </div>
                     <button onClick={() => onDeleteMethod(method.id)} className="text-slate-300 hover:text-red-500 transition-colors"><Trash2 size={14}/></button>
                  </div>
                ))}
              </div>
              <div className="mt-6 p-4 bg-emerald-50 rounded-2xl border border-emerald-100 flex items-center gap-3">
                <Lock size={20} className="text-emerald-600 flex-shrink-0" />
                <p className="text-[10px] text-emerald-800 leading-relaxed font-medium">Secured by Malaysian Banking AI Standards.</p>
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

const NGODashboard = ({ ngoBank, setNgoBank }: { ngoBank: any, setNgoBank: any }) => {
  const [isVerified, setIsVerified] = useState(false);
  const [tab, setTab] = useState<'needs' | 'items'>('needs');
  const [showReportModal, setShowReportModal] = useState(false);
  const [showItemModal, setShowItemModal] = useState(false);

  if (!isVerified) return (
    <div className="max-w-2xl mx-auto space-y-6 animate-in slide-in-from-bottom-4 duration-500">
      <div className="bg-white p-8 rounded-3xl border border-slate-100 shadow-sm text-center">
        <div className="bg-blue-50 w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-6 text-blue-600"><FileCheck className="w-8 h-8" /></div>
        <h2 className="text-2xl font-bold text-slate-800 mb-2">NGO Secure Console</h2>
        <p className="text-slate-500 text-sm mb-8">Official MERCY Malaysia Portal. Enter your project PIN.</p>
        <input type="text" placeholder="Project PIN" className="w-full bg-slate-50 border border-slate-200 p-4 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 mb-4 text-center tracking-[1em]" />
        <button onClick={() => setIsVerified(true)} className="w-full bg-blue-600 text-white py-4 rounded-xl font-bold shadow-lg hover:bg-blue-700 transition">Enter Secure Portal</button>
      </div>
    </div>
  );

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      {showReportModal && <FieldReportModal onCancel={() => setShowReportModal(false)} onComplete={(r) => { setShowReportModal(false); alert('Field Report Published Successfully!'); }} />}
      {showItemModal && <ItemRequestModal onCancel={() => setShowItemModal(false)} onComplete={(i) => { setShowItemModal(false); alert('Item Request Published Successfully!'); }} />}

      <header className="flex flex-col md:flex-row justify-between md:items-center gap-4">
        <div className="flex items-center gap-4">
          <div className="bg-blue-600 p-3 rounded-2xl text-white shadow-xl shadow-blue-100"><Building2 className="w-6 h-6" /></div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-bold text-slate-800">MERCY Malaysia</h1>
              <span className="bg-blue-100 text-blue-600 text-[10px] font-bold px-2 py-0.5 rounded-full flex items-center gap-1"><ShieldCheck size={10} /> Official Partner</span>
            </div>
            <p className="text-slate-500 text-sm">PPM-001-10-XXXX • Relief Operational Hub</p>
          </div>
        </div>
        <div className="flex gap-3">
          <button onClick={() => setShowReportModal(true)} className="bg-blue-600 text-white px-6 py-2 rounded-xl text-xs font-bold shadow-lg flex items-center gap-2"><FileText size={16} /> New Field Report</button>
        </div>
      </header>

      <div className="flex gap-4 border-b border-slate-200">
        <button onClick={() => setTab('needs')} className={`px-4 py-2 text-sm font-bold transition-colors ${tab === 'needs' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-slate-400'}`}>Operational Areas</button>
        <button onClick={() => setTab('items')} className={`px-4 py-2 text-sm font-bold transition-colors ${tab === 'items' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-slate-400'}`}>Physical Goods Requests</button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2">
          {tab === 'needs' ? (
            <section className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden animate-in fade-in">
              <div className="p-6 border-b border-slate-50 flex justify-between items-center"><h2 className="font-bold text-slate-800">Managed Disaster Zones</h2></div>
              <div className="overflow-x-auto">
                <table className="w-full text-left">
                  <thead className="bg-slate-50/50">
                    <tr className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">
                      <th className="px-6 py-4">Location</th><th className="px-6 py-4">Status</th><th className="px-6 py-4">Urgency</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-50">
                    {MOCK_NEEDS.map(need => (
                      <tr key={need.id} className="hover:bg-slate-50/50 transition">
                        <td className="px-6 py-4 text-sm font-bold text-slate-800">{need.location}</td>
                        <td className="px-6 py-4"><span className="bg-blue-50 text-blue-600 text-[10px] font-bold px-2 py-1 rounded">Monitoring</span></td>
                        <td className="px-6 py-4"><div className="w-full bg-slate-100 h-1.5 rounded-full"><div className="bg-blue-600 h-full rounded-full" style={{ width: `${need.score}%` }}></div></div></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          ) : (
            <section className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden animate-in fade-in">
              <div className="p-6 border-b border-slate-50 flex justify-between items-center">
                <h2 className="font-bold text-slate-800">Inventory Needed</h2>
                <button onClick={() => setShowItemModal(true)} className="text-[10px] font-bold bg-blue-50 text-blue-600 px-3 py-1.5 rounded-lg flex items-center gap-2"><Plus size={14}/> Request New Item</button>
              </div>
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4">
                {MOCK_NEEDS[0].physicalNeeds.map(item => (
                  <div key={item} className="p-4 bg-slate-50 border border-slate-100 rounded-2xl flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Package className="text-blue-500" size={18}/>
                      <span className="text-sm font-bold text-slate-800">{item}</span>
                    </div>
                    <span className="text-[10px] font-bold text-red-600 bg-red-50 px-2 py-0.5 rounded-full">Urgent</span>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>

        <div className="space-y-6">
           <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
              <h3 className="font-bold text-slate-800 flex items-center gap-2 mb-6"><Banknote size={18} className="text-blue-600" /> Funds Summary</h3>
              <div className="p-4 bg-blue-50 rounded-2xl border border-blue-100">
                <p className="text-[10px] font-bold text-blue-600 uppercase mb-2">Relief Account</p>
                <p className="text-sm font-bold text-slate-800">{ngoBank.name}</p>
                <p className="text-xs text-slate-500">{ngoBank.account}</p>
              </div>
              <button className="w-full mt-4 bg-slate-50 text-slate-500 py-3 rounded-xl text-xs font-bold border border-slate-200">View Detailed Statements</button>
           </div>
           
           <div className="bg-blue-600 p-6 rounded-3xl shadow-xl shadow-blue-100 text-white flex flex-col items-center text-center">
             <QrCode size={48} className="mb-4 opacity-50"/>
             <h4 className="font-bold mb-1">Verify Receipt</h4>
             <p className="text-[10px] text-blue-100 leading-relaxed mb-6">Scan donor QR codes at drop-off points to confirm item arrivals.</p>
             <button className="w-full bg-white text-blue-600 py-3 rounded-xl font-bold text-xs shadow-lg">Open Scanner</button>
           </div>
        </div>
      </div>
    </div>
  );
};

const NeedsMap = ({ onDonate, role }: { onDonate: (need: any) => void, role: 'donor' | 'ngo' }) => {
  const [filter, setFilter] = useState('All');
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const categories = ['All', 'Flood Relief', 'Food Security', 'Medical Aid'];
  const filteredNeeds = filter === 'All' ? MOCK_NEEDS : MOCK_NEEDS.filter(n => n.category === filter);

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <header className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Malaysian Relief Heatmap</h1>
          <p className="text-slate-500 text-sm">AI-correlated signal tracking for humanitarian aid.</p>
        </div>
        <div className="flex items-center gap-2 bg-white p-1 rounded-xl border border-slate-200 shadow-sm overflow-x-auto">
          {categories.map(cat => (
            <button key={cat} onClick={() => setFilter(cat)} className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${filter === cat ? 'bg-emerald-600 text-white shadow-md' : 'text-slate-500 hover:bg-slate-50'}`}>
              {cat}
            </button>
          ))}
        </div>
      </header>
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div className="lg:col-span-8 bg-slate-200 rounded-3xl min-h-[500px] relative overflow-hidden border border-slate-200 shadow-inner bg-[url('https://images.unsplash.com/photo-1548337138-e87d889cc369?auto=format&fit=crop&q=80&w=1200')] bg-cover bg-center">
          <div className="absolute inset-0 bg-emerald-900/10 backdrop-blur-[1px]"></div>
          {filteredNeeds.map((need) => {
            const positions: Record<number, { top: string, left: string }> = { 1: { top: '25%', left: '45%' }, 2: { top: '15%', left: '35%' }, 3: { top: '45%', left: '85%' } };
            const pos = positions[need.id] || { top: '50%', left: '50%' };
            return (
              <button key={need.id} onClick={() => setSelectedId(need.id)} className={`absolute w-8 h-8 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-lg flex items-center justify-center transition-all ${selectedId === need.id ? 'scale-125 ring-2 ring-emerald-500' : ''} ${need.score > 85 ? 'bg-red-500' : 'bg-emerald-500'}`} style={pos}>
                <AlertCircle size={14} className="text-white" />
              </button>
            );
          })}
        </div>
        <div className="lg:col-span-4 space-y-4 max-h-[500px] overflow-y-auto pr-2 custom-scrollbar">
          {filteredNeeds.map((need) => (
            <div key={need.id} onClick={() => setSelectedId(need.id)} className={`bg-white p-5 rounded-2xl border transition-all cursor-pointer ${selectedId === need.id ? 'border-emerald-500 shadow-md ring-1 ring-emerald-500' : 'border-slate-100 hover:border-slate-300'}`}>
              <div className="flex justify-between text-[10px] font-bold uppercase text-slate-400 mb-2"><span>{need.category}</span><span className="text-emerald-600">Verified</span></div>
              <h3 className="font-bold text-slate-800">{need.location}</h3>
              <p className="text-xs text-slate-500 mt-1 mb-4">{need.description}</p>
              {role === 'donor' && (
                <button onClick={(e) => { e.stopPropagation(); onDonate(need); }} className="w-full bg-emerald-600 text-white py-2 rounded-xl text-xs font-bold flex items-center justify-center gap-2 shadow-lg shadow-emerald-50 hover:bg-emerald-700 transition"><ArrowUpRight size={14} /> Contribute Now</button>
              )}
              {role === 'ngo' && (
                <div className="w-full bg-slate-50 text-slate-400 py-2 rounded-xl text-[10px] font-bold flex items-center justify-center gap-2 border border-slate-100"><ShieldCheck size={12} /> Logged by {need.verifiedBy}</div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const AIAdvisor = ({ role }: { role: 'donor' | 'ngo' }) => {
  const initialMessage = role === 'ngo' 
    ? "Selamat Sejahtera! I am KitaCare NGO Support AI. I can assist you with managing physical item needs, verifying drop-off receipts, or checking disbursement logs. How can I help your mission today?"
    : "Selamat Sejahtera! I am KitaCare AI. I can help you find verified NGOs, manage your donation wallet, or find the nearest drop-off point for physical items. What would you like to know?";

  const systemPrompt = role === 'ngo'
    ? "You are KitaCare NGO AI. Help Malaysian NGOs with logistics, verifying Donation IDs, and listing physical needs. Professional and operational tone. Use terms like 'ROS registration', 'Drop-off point', 'Inventory' and 'Disbursement'."
    : "You are KitaCare AI for Donors. Help Malaysians with charitable transparency, wallet security, and item matching. Warm and empathetic tone. Use terms like 'Sadaqah', 'Infaq', 'MyKad', and 'Impact Tracking'.";

  const [messages, setMessages] = useState<{ role: 'user' | 'ai', content: string }[]>([
    { role: 'ai', content: initialMessage }
  ]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;
    const userMessage = input;
    setInput("");
    setMessages(prev => [...prev, { role: 'user', content: userMessage }]);
    setIsLoading(true);
    try {
      /**
       * [BACKEND]: EXTERNAL INTEGRATION
       * Gemini API is used directly. Consider proxying through your own backend for security/auditing.
       */
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: userMessage,
        config: { systemInstruction: systemPrompt }
      });
      setMessages(prev => [...prev, { role: 'ai', content: response.text || "I'm sorry, I couldn't reach the advisor. Please try again." }]);
    } catch (e) {
      setMessages(prev => [...prev, { role: 'ai', content: "Error connecting to AI. Please check your internet." }]);
    } finally { setIsLoading(false); }
  };

  return (
    <div className="max-w-4xl mx-auto bg-white rounded-3xl border border-slate-100 shadow-sm flex flex-col h-[600px] overflow-hidden">
      <div className="p-6 border-b border-slate-50 flex items-center gap-3 bg-slate-50/50">
        <div className={`${role === 'ngo' ? 'bg-blue-600' : 'bg-emerald-600'} p-2 rounded-xl text-white shadow-lg`}><MessageSquare size={20} /></div>
        <div><h2 className="text-sm font-bold text-slate-800">KitaCare {role.toUpperCase()} AI</h2><p className="text-[10px] text-emerald-600 font-bold uppercase tracking-wider">Expert Advisor</p></div>
      </div>
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-6 space-y-4 bg-slate-50/20">
        {messages.map((msg, idx) => (
          <div key={idx} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[85%] p-4 rounded-2xl text-sm ${msg.role === 'user' ? (role === 'ngo' ? 'bg-blue-600' : 'bg-emerald-600') + ' text-white shadow-md rounded-tr-none' : 'bg-white text-slate-700 border border-slate-100 shadow-sm rounded-tl-none'}`}>{msg.content}</div>
          </div>
        ))}
        {isLoading && <div className="flex justify-start"><div className="bg-white p-3 rounded-2xl rounded-tl-none border border-slate-100 animate-pulse text-xs text-slate-400">Consulting KitaCare Knowledge...</div></div>}
      </div>
      <div className="p-4 border-t border-slate-50 bg-white flex gap-2">
        <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleSend()} placeholder={role === 'ngo' ? "Ask about receipt verification or logistics..." : "Ask about donation points or tax certificates..."} className="flex-1 bg-slate-50 border border-slate-200 p-4 rounded-xl outline-none focus:ring-2 focus:ring-emerald-500 text-sm" />
        <button onClick={handleSend} disabled={isLoading} className={`${role === 'ngo' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-emerald-600 hover:bg-emerald-700'} text-white p-4 rounded-xl transition disabled:opacity-50`}><Send size={20} /></button>
      </div>
    </div>
  );
};

const DonorAnalytics = ({ donations }: { donations: any[] }) => {
  const totalRM = donations.filter(d => d.type === 'money').reduce((sum, d) => sum + d.amount, 0);
  const totalItems = donations.filter(d => d.type === 'item').length;
  
  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">My Charitable Journey</h1>
        <p className="text-slate-500 text-sm">Quantifying your impact across the Malaysian community.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
           <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-4">Cash Support</h3>
           <p className="text-3xl font-bold text-emerald-600">RM {totalRM}</p>
        </div>
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
           <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-4">Physical Items</h3>
           <p className="text-3xl font-bold text-blue-600">{totalItems} Donated</p>
        </div>
        <div className="md:col-span-2 bg-emerald-900 text-white p-6 rounded-3xl shadow-xl flex items-center justify-between relative overflow-hidden">
           <Award className="absolute -right-4 -bottom-4 w-32 h-32 opacity-10 rotate-12" />
           <div className="relative z-10">
              <p className="text-xs font-bold uppercase tracking-widest opacity-80">Philanthropy Tier</p>
              <h4 className="text-2xl font-bold">Community Pillar</h4>
              <p className="text-[10px] mt-2 opacity-60">You are in the top 10% of Malaysian supporters this year.</p>
           </div>
           <div className="bg-emerald-400 text-emerald-900 px-4 py-2 rounded-xl font-black text-sm relative z-10">GOLD</div>
        </div>
      </div>

      <section className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-slate-50 flex justify-between items-center"><h2 className="font-bold text-slate-800">Contribution Audit & Certificates</h2></div>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-slate-50/50">
              <tr className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">
                <th className="px-6 py-4">Date</th>
                <th className="px-6 py-4">Type</th>
                <th className="px-6 py-4">Cause</th>
                <th className="px-6 py-4">NGO</th>
                <th className="px-6 py-4">Impact</th>
                <th className="px-6 py-4">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {donations.map(donation => (
                <tr key={donation.id} className="hover:bg-slate-50/50 transition">
                  <td className="px-6 py-4 text-xs text-slate-500">{donation.date}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded text-[10px] font-bold ${donation.type === 'money' ? 'bg-emerald-50 text-emerald-600' : 'bg-blue-50 text-blue-600'}`}>
                      {donation.type.toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm font-bold text-slate-800">{donation.target}</td>
                  <td className="px-6 py-4 text-xs text-slate-600">{donation.ngo}</td>
                  <td className="px-6 py-4 text-xs font-bold text-slate-500">{donation.type === 'money' ? `RM ${donation.amount}` : donation.itemDetails}</td>
                  <td className="px-6 py-4">
                    <button onClick={() => alert('Generating e-Certificate...')} className="flex items-center gap-1.5 bg-slate-100 text-slate-600 px-3 py-1.5 rounded-lg text-[10px] font-bold hover:bg-emerald-600 hover:text-white transition">
                      <Download size={12} /> Certificate
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
};

const NGOAnalytics = () => {
  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">Mission Operational Data</h1>
        <p className="text-slate-500 text-sm">Tracking logistics speed, fund health, and physical inventory.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
           <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-4">Lorry Dispatch Rate</h3>
           <div className="flex items-end gap-2 h-24">
             {[30, 60, 45, 80, 55, 90, 70].map((h, i) => (
               <div key={i} className="flex-1 bg-blue-100 rounded-t-lg transition-all duration-1000" style={{ height: `${h}%` }}></div>
             ))}
           </div>
           <p className="mt-4 text-xs font-bold text-slate-800">Avg. delivery: <span className="text-blue-600">3.4 Days</span></p>
        </div>
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm flex flex-col justify-center text-center">
           <Truck className="mx-auto text-blue-600 mb-2" size={32}/>
           <p className="text-2xl font-bold text-slate-800">84 Active Drops</p>
           <p className="text-xs font-bold text-slate-400 uppercase mt-1">Incoming Physical Goods</p>
        </div>
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm flex flex-col justify-center text-center">
           <p className="text-4xl font-bold text-blue-600">98.2%</p>
           <p className="text-xs font-bold text-slate-400 uppercase mt-2 tracking-widest">Transparency Score</p>
        </div>
      </div>
    </div>
  );
};

// ==========================================
// 5. AUTH SCREEN (Refined Login & Sign Up)
// ==========================================
const SignUpForm = ({ role, onCancel, onComplete }: { role: 'donor' | 'ngo', onCancel: () => void, onComplete: () => void }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    id: '',
    regNo: '', // For NGO
    email: '',
    password: ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    /**
     * [BACKEND]: API INTERVENTION
     * Replace setTimeout with POST /api/auth/register
     */
    setTimeout(() => {
      setLoading(false);
      onComplete();
    }, 1500);
  };

  return (
    <div className="space-y-6 animate-in slide-in-from-right-4">
      <div className="flex items-center gap-2 mb-2">
        <button onClick={onCancel} className="text-slate-400 hover:text-slate-800 p-1 rounded-lg transition-colors">
          <ChevronLeft size={20} />
        </button>
        <span className="text-[10px] bg-slate-100 px-2 py-1 rounded text-slate-500 font-bold uppercase tracking-wider">New {role} registration</span>
      </div>

      <div className="space-y-1">
        <h2 className="text-2xl font-bold text-slate-800">Create Account</h2>
        <p className="text-sm text-slate-500">Provide official details to verify your identity.</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-3">
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Official Name</label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input 
                required
                type="text" 
                placeholder={role === 'ngo' ? "Official NGO Name (MERCY Malaysia)" : "Full Name as per MyKad"} 
                className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500 transition-all text-sm"
                value={formData.name}
                onChange={e => setFormData({...formData, name: e.target.value})}
              />
            </div>
          </div>

          {role === 'ngo' && (
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Registration Number (ROS/SSM)</label>
              <div className="relative">
                <ShieldCheck className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input 
                  required
                  type="text" 
                  placeholder="PPM-001-10-XXXX" 
                  className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 transition-all text-sm font-mono"
                  value={formData.regNo}
                  onChange={e => setFormData({...formData, regNo: e.target.value})}
                />
              </div>
            </div>
          )}

          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Identity ID (MyKad/Passport)</label>
            <div className="relative">
              <Receipt className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input 
                required
                type="text" 
                placeholder="XXXXXX-XX-XXXX" 
                className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500 transition-all text-sm"
                value={formData.id}
                onChange={e => setFormData({...formData, id: e.target.value})}
              />
            </div>
          </div>

          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Official Email</label>
            <div className="relative">
              <Send className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input 
                required
                type="email" 
                placeholder="contact@email.com" 
                className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500 transition-all text-sm"
                value={formData.email}
                onChange={e => setFormData({...formData, email: e.target.value})}
              />
            </div>
          </div>

          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Secure Password</label>
            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input 
                required
                type="password" 
                placeholder="••••••••" 
                className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-3 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500 transition-all text-sm"
                value={formData.password}
                onChange={e => setFormData({...formData, password: e.target.value})}
              />
            </div>
          </div>
        </div>

        <button 
          type="submit"
          disabled={loading}
          className={`w-full py-4 rounded-2xl font-bold shadow-lg transition flex items-center justify-center gap-2 text-white ${role === 'ngo' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-emerald-600 hover:bg-emerald-700'}`}
        >
          {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : <>Register Account <ArrowRight size={18} /></>}
        </button>
      </form>
    </div>
  );
};

const AuthScreen = ({ onLogin }: { onLogin: (role: 'donor' | 'ngo') => void }) => {
  const [view, setView] = useState<'selection' | 'login' | 'signup'>('selection');
  const [selectedRole, setSelectedRole] = useState<'donor' | 'ngo' | null>(null);

  const handleRoleSelect = (role: 'donor' | 'ngo') => {
    setSelectedRole(role);
    setView('login');
  };

  const reset = () => {
    setView('selection');
    setSelectedRole(null);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-6 bg-[url('https://images.unsplash.com/photo-1548337138-e87d889cc369?auto=format&fit=crop&q=80&w=2000')] bg-cover bg-center relative">
      <div className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"></div>
      
      <div className="relative z-10 w-full max-w-4xl grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Left Side: Branding */}
        <div className="flex flex-col justify-center text-white space-y-6">
          <div className="flex items-center gap-3">
            <div className="bg-emerald-600 p-3 rounded-2xl text-white shadow-xl shadow-emerald-900/20">
              <Heart className="w-8 h-8 fill-current" />
            </div>
            <h1 className="text-4xl font-black tracking-tight">KitaCare <span className="text-emerald-400">AI</span></h1>
          </div>
          <div className="space-y-4">
            <h2 className="text-5xl font-bold leading-tight italic">Rakyat Menjaga Rakyat.</h2>
            <p className="text-lg text-slate-300 max-w-md">
              The Malaysian disaster relief ecosystem powered by AI. Transparency, real-time logistics, and verified impact.
            </p>
          </div>
          <div className="flex flex-wrap gap-4 pt-4">
            <div className="flex items-center gap-2 bg-white/10 px-4 py-2 rounded-full backdrop-blur-md border border-white/20">
              <ShieldCheck size={16} className="text-emerald-400" />
              <span className="text-[10px] font-bold uppercase tracking-widest">Verified ROS/SSM NGOs</span>
            </div>
            <div className="flex items-center gap-2 bg-white/10 px-4 py-2 rounded-full backdrop-blur-md border border-white/20">
              <Zap size={16} className="text-blue-400" />
              <span className="text-[10px] font-bold uppercase tracking-widest">Real-time Relief Map</span>
            </div>
          </div>
        </div>

        {/* Right Side: Interactive Forms */}
        <div className="bg-white rounded-[40px] p-8 md:p-10 shadow-2xl flex flex-col justify-center min-h-[500px]">
          {view === 'selection' && (
            <div className="space-y-8 animate-in fade-in zoom-in-95">
              <div>
                <h3 className="text-2xl font-bold text-slate-800">Selamat Datang</h3>
                <p className="text-slate-500">Select your account type to continue</p>
              </div>

              <div className="space-y-4">
                <button 
                  onClick={() => handleRoleSelect('donor')}
                  className="w-full group p-6 bg-slate-50 border-2 border-slate-100 rounded-3xl hover:border-emerald-500 hover:bg-emerald-50 transition-all text-left flex items-center gap-6"
                >
                  <div className="bg-emerald-100 text-emerald-600 p-4 rounded-2xl group-hover:bg-emerald-600 group-hover:text-white transition shadow-sm">
                    <User size={24} />
                  </div>
                  <div className="flex-1">
                    <p className="font-bold text-xl text-slate-800">Individual Donor</p>
                    <p className="text-sm text-slate-500">Track impact of your contributions</p>
                  </div>
                  <ArrowRight className="text-slate-300 group-hover:text-emerald-500 group-hover:translate-x-1 transition" size={24} />
                </button>

                <button 
                  onClick={() => handleRoleSelect('ngo')}
                  className="w-full group p-6 bg-slate-50 border-2 border-slate-100 rounded-3xl hover:border-blue-500 hover:bg-blue-50 transition-all text-left flex items-center gap-6"
                >
                  <div className="bg-blue-100 text-blue-600 p-4 rounded-2xl group-hover:bg-blue-600 group-hover:text-white transition shadow-sm">
                    <Building2 size={24} />
                  </div>
                  <div className="flex-1">
                    <p className="font-bold text-xl text-slate-800">Malaysian NGO</p>
                    <p className="text-sm text-slate-500">Manage field ops & verified needs</p>
                  </div>
                  <ArrowRight className="text-slate-300 group-hover:text-blue-500 group-hover:translate-x-1 transition" size={24} />
                </button>
              </div>
            </div>
          )}

          {view === 'login' && selectedRole && (
            <div className="space-y-6 animate-in slide-in-from-right-4">
              <div className="flex items-center gap-2">
                <button onClick={reset} className="text-slate-400 hover:text-slate-800 p-1 rounded-lg transition-colors"><ChevronLeft size={20} /></button>
                <h3 className="text-xl font-bold text-slate-800 uppercase tracking-tight">{selectedRole} Login</h3>
              </div>
              
              <div className="space-y-4">
                <div className="relative">
                  <Send className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input type="email" placeholder="Email Address" className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-4 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500" />
                </div>
                <div className="relative">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input type="password" placeholder="Password" className="w-full bg-slate-50 border border-slate-200 pl-11 pr-4 py-4 rounded-2xl outline-none focus:ring-2 focus:ring-emerald-500" />
                </div>
              </div>

              <button 
                /**
                 * [BACKEND]: API INTERVENTION
                 * Replace role-bypass with POST /api/auth/login
                 */
                onClick={() => onLogin(selectedRole)}
                className={`w-full py-4 rounded-2xl font-bold shadow-lg text-white transition-all ${selectedRole === 'ngo' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-emerald-600 hover:bg-emerald-700'}`}
              >
                Sign In
              </button>

              <div className="text-center">
                <button onClick={() => setView('signup')} className="text-sm font-bold text-slate-400 hover:text-emerald-600 transition-colors">
                  Don't have an account? <span className="underline">Create New Account</span>
                </button>
              </div>
            </div>
          )}

          {view === 'signup' && selectedRole && (
            <SignUpForm 
              role={selectedRole} 
              onCancel={() => setView('login')} 
              onComplete={() => onLogin(selectedRole)} 
            />
          )}

          <p className="mt-8 text-center text-[10px] text-slate-400 font-bold uppercase tracking-widest">
            Compliance with Malaysia ROS/SSM Regulations
          </p>
        </div>
      </div>
    </div>
  );
};

// ==========================================
// 6. APP SHELL
// ==========================================
const App = () => {
  const [role, setRole] = useState<'donor' | 'ngo' | null>(null);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isSidebarOpen, setSidebarOpen] = useState(false);
  const [paymentNeed, setPaymentNeed] = useState<any>(null);
  /**
   * [BACKEND]: MOCK STATE
   * Pull user profile / payment methods from central user service.
   */
  const [savedMethods, setSavedMethods] = useState([ { id: '1', bank: 'Maybank', account: '1140-XXXX-5521' } ]);
  const [ngoBank, setNgoBank] = useState({ name: 'Maybank', account: '5140-XXXX-2241', holder: 'MERCY Malaysia Relief Fund' });

  const addMethod = (method: any) => setSavedMethods([...savedMethods, method]);
  const deleteMethod = (id: string) => setSavedMethods(savedMethods.filter(m => m.id !== id));

  if (!role) return <AuthScreen onLogin={setRole} />;

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard': return role === 'donor' ? <DonorDashboard donations={INITIAL_DONATIONS} savedMethods={savedMethods} onAddMethod={addMethod} onDeleteMethod={deleteMethod} /> : <NGODashboard ngoBank={ngoBank} setNgoBank={setNgoBank} />;
      case 'map': return <NeedsMap onDonate={setPaymentNeed} role={role} />;
      case 'advisor': return <AIAdvisor role={role} />;
      case 'analytics': return role === 'ngo' ? <NGOAnalytics /> : <DonorAnalytics donations={INITIAL_DONATIONS} />;
      default: return <DonorDashboard donations={INITIAL_DONATIONS} savedMethods={savedMethods} onAddMethod={addMethod} onDeleteMethod={deleteMethod} />;
    }
  };

  return (
    <div className="flex min-h-screen bg-slate-50 relative">
      {paymentNeed && <DonationModal need={paymentNeed} role={role} savedMethods={savedMethods} onCancel={() => setPaymentNeed(null)} onComplete={() => { setPaymentNeed(null); alert('Contribution Successful! Thank you for your kindness.'); }} />}
      {isSidebarOpen && <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-30 lg:hidden" onClick={() => setSidebarOpen(false)} />}
      
      <aside className={`fixed inset-y-0 left-0 z-40 w-64 bg-white border-r border-slate-200 transform transition-transform duration-300 lg:translate-x-0 lg:static lg:block ${isSidebarOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full'}`}>
        <div className="p-6 flex flex-col h-full">
          <div className="flex items-center gap-3 mb-12">
            <div className={`${role === 'ngo' ? 'bg-blue-600' : 'bg-emerald-600'} p-2 rounded-xl text-white shadow-lg`}><Heart className="w-5 h-5 fill-current" /></div>
            <span className="text-xl font-bold text-slate-800">KitaCare <span className={role === 'ngo' ? 'text-blue-600' : 'text-emerald-600'}>AI</span></span>
          </div>
          <nav className="space-y-1 flex-1">
            <button onClick={() => { setActiveTab('dashboard'); setSidebarOpen(false); }} className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl font-bold text-sm ${activeTab === 'dashboard' ? (role === 'ngo' ? 'bg-blue-50 text-blue-700 shadow-sm' : 'bg-emerald-50 text-emerald-700 shadow-sm') : 'text-slate-400 hover:bg-slate-50'}`}><LayoutDashboard size={20}/> {role === 'ngo' ? 'Mission Hub' : 'Dashboard'}</button>
            <button onClick={() => { setActiveTab('map'); setSidebarOpen(false); }} className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl font-bold text-sm ${activeTab === 'map' ? (role === 'ngo' ? 'bg-blue-50 text-blue-700 shadow-sm' : 'bg-emerald-50 text-emerald-700 shadow-sm') : 'text-slate-400 hover:bg-slate-50'}`}><MapIcon size={20}/> Relief Map</button>
            <button onClick={() => { setActiveTab('advisor'); setSidebarOpen(false); }} className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl font-bold text-sm ${activeTab === 'advisor' ? (role === 'ngo' ? 'bg-blue-50 text-blue-700 shadow-sm' : 'bg-emerald-50 text-emerald-700 shadow-sm') : 'text-slate-400 hover:bg-slate-50'}`}><MessageSquare size={20}/> AI Advisor</button>
            <button onClick={() => { setActiveTab('analytics'); setSidebarOpen(false); }} className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl font-bold text-sm ${activeTab === 'analytics' ? (role === 'ngo' ? 'bg-blue-50 text-blue-700 shadow-sm' : 'bg-emerald-50 text-emerald-700 shadow-sm') : 'text-slate-400 hover:bg-slate-50'}`}><BarChart3 size={20}/> {role === 'ngo' ? 'Logistics Data' : 'My Impact'}</button>
          </nav>
          <div className="pt-6 border-t border-slate-100">
            <div className="flex items-center gap-3 mb-6 px-4">
              <div className="w-8 h-8 bg-slate-100 rounded-full flex items-center justify-center font-bold text-xs text-slate-500 border border-slate-200">{role === 'donor' ? 'D' : 'N'}</div>
              <div className="flex-1 overflow-hidden">
                <p className="text-xs font-bold text-slate-700 truncate">{role === 'donor' ? 'Ahmad S.' : 'MERCY MY'}</p>
                <p className="text-[10px] text-slate-400 uppercase font-bold tracking-widest">{role}</p>
              </div>
            </div>
            <button onClick={() => setRole(null)} className="w-full flex items-center gap-3 px-4 py-2 text-sm font-bold text-red-500 hover:bg-red-50 rounded-xl transition-colors"><LogOut size={16} /> Logout</button>
          </div>
        </div>
      </aside>
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="lg:hidden bg-white border-b border-slate-200 h-16 flex items-center px-4 sticky top-0 z-20 shadow-sm">
          <button onClick={() => setSidebarOpen(true)} className="p-2 -ml-2 text-slate-600 hover:bg-slate-50 rounded-lg"><Menu size={24} /></button>
          <span className="ml-4 font-bold text-slate-800">KitaCare AI</span>
        </header>
        <main className="flex-1 overflow-y-auto p-6 lg:p-10">{renderContent()}</main>
      </div>
    </div>
  );
};

const root = createRoot(document.getElementById('root')!);
root.render(<App />);
