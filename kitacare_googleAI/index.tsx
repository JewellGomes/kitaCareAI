
import React, { useState, useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import { 
  Heart, 
  Map as MapIcon, 
  LayoutDashboard, 
  MessageSquare, 
  ChevronRight, 
  AlertCircle, 
  CheckCircle2, 
  Smartphone, 
  TrendingUp,
  MapPin,
  Search,
  BookOpen,
  Code,
  Layers,
  Zap,
  ShieldCheck,
  Menu,
  X,
  Send,
  Package,
  Truck,
  UserCheck,
  Receipt
} from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

// Initialize Gemini
const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

// Mock Data for Malaysia Needs
const MALAYSIA_NEEDS = [
  { id: 1, state: "Kelantan", area: "Rantau Panjang", need: "Food & Clean Water", urgency: "Critical", score: 92, ngos: ["MERCY Malaysia", "MyCARE"] },
  { id: 2, state: "Sabah", area: "Pitas", need: "Healthcare Equipment", urgency: "Critical", score: 88, ngos: ["The Hope Branch", "Red Crescent"] },
  { id: 3, state: "Selangor", area: "Shah Alam", need: "Urban Welfare Support", urgency: "Moderate", score: 45, ngos: ["Kechara Soup Kitchen"] },
  { id: 4, state: "Sarawak", area: "Kapit", need: "School Supplies", urgency: "Moderate", score: 55, ngos: ["Bantu Sarawak"] },
  { id: 5, state: "Johor", area: "Batu Pahat", need: "Elderly Care", urgency: "Low", score: 25, ngos: ["PERTIWI"] },
];

const IMPACT_STATS = [
  { label: "Families Helped", value: "12,402", color: "text-emerald-600" },
  { label: "Active Donors", value: "3,850", color: "text-blue-600" },
  { label: "NGO Partners", value: "42", color: "text-purple-600" },
];

const DONATION_JOURNEY = {
  id: "KC-88421",
  amount: "RM 150.00",
  date: "Oct 24, 2024",
  target: "Kelantan Flood Relief",
  steps: [
    { label: "Received", status: "complete", date: "Oct 24", icon: <CheckCircle2 className="w-4 h-4" /> },
    { label: "Purchased", status: "complete", date: "Oct 25", detail: "2x Hygiene Kits, 1x 5kg Rice", icon: <Package className="w-4 h-4" /> },
    { label: "In Transit", status: "active", date: "Oct 26", detail: "Lorry heading to Rantau Panjang", icon: <Truck className="w-4 h-4" /> },
    { label: "Delivered", status: "pending", date: "Est Oct 27", icon: <UserCheck className="w-4 h-4" /> }
  ]
};

const FLUTTER_GUIDE = [
  {
    step: 1,
    title: "Project Setup",
    icon: <Code className="w-6 h-6" />,
    description: "Install Flutter SDK and run 'flutter create kitacare_app'. Add dependencies like 'google_generative_ai' for the AI and 'google_maps_flutter' for the map view.",
    code: "dependencies:\n  flutter:\n    sdk: flutter\n  google_generative_ai: ^0.4.0\n  google_maps_flutter: ^2.5.0\n  provider: ^6.1.1"
  },
  {
    step: 2,
    title: "UI Architecture",
    icon: <Layers className="w-6 h-6" />,
    description: "Use a BottomNavigationBar for main navigation. Create a Dashboard screen using CustomScrollView and SliverAppBar for a premium feel.",
    code: "Scaffold(\n  body: _screens[_currentIndex],\n  bottomNavigationBar: BottomNavigationBar(...),\n)"
  },
  {
    step: 3,
    title: "The AI Advisor",
    icon: <Zap className="w-6 h-6" />,
    description: "Create a Service class for Gemini. Send prompts that ask for specific Malaysian NGO recommendations. Handle streams for real-time chat bubbles.",
    code: "final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: apiKey);\nfinal response = await model.generateContent([Content.text(prompt)]);"
  },
  {
    step: 4,
    title: "Interactive Needs Map",
    icon: <MapIcon className="w-6 h-6" />,
    description: "Implement Google Maps with custom markers. Color-code markers based on the 'Need Score' (Red for scores > 80).",
    code: "GoogleMap(\n  initialCameraPosition: _kMalaysia,\n  markers: _markers,\n)"
  },
  {
    step: 5,
    title: "Impact Tracker UI",
    icon: <Receipt className="w-6 h-6" />,
    description: "Build a vertical 'Transparency Timeline' using a ListView of custom Row widgets. This builds deep trust with your Malaysian donors.",
    code: "// Flutter Timeline Example\nColumn(\n  children: steps.map((s) => Row(\n    children: [\n       Icon(s.icon),\n       Text(s.label),\n       if (!last) VerticalDivider(),\n    ]\n  )).toList(),\n)"
  },
  {
    step: 6,
    title: "Testing & Deployment",
    icon: <ShieldCheck className="w-6 h-6" />,
    description: "Test on Android and iOS emulators. Use 'flutter build apk' for distribution to local NGOs for beta testing.",
    code: "flutter test\nflutter build appbundle"
  }
];

const App = () => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isSidebarOpen, setSidebarOpen] = useState(true);
  const [chatMessage, setChatMessage] = useState('');
  const [trackingId, setTrackingId] = useState('');
  const [chatHistory, setChatHistory] = useState<{ role: 'user' | 'ai', text: string }[]>([
    { role: 'ai', text: "Selamat Datang! I am KitaCare AI. How can I help you support Malaysian communities today?" }
  ]);
  const [isLoading, setIsLoading] = useState(false);

  const handleSendMessage = async () => {
    if (!chatMessage.trim()) return;

    const userMsg = chatMessage;
    setChatHistory(prev => [...prev, { role: 'user', text: userMsg }]);
    setChatMessage('');
    setIsLoading(true);

    try {
      const response = await ai.models.generateContent({
        model: "gemini-3-flash-preview",
        contents: `You are KitaCare AI, an expert in Malaysian humanitarian aid.
          The user says: "${userMsg}"
          Recommend specific Malaysian NGOs (like MERCY Malaysia, MyCARE, Islamic Relief Malaysia, or Kechara) 
          based on their request. Be polite, concise, and professional. 
          Use a mix of English and common Malaysian greetings.`,
      });

      setChatHistory(prev => [...prev, { role: 'ai', text: response.text || "I apologize, I'm having trouble connecting to the network." }]);
    } catch (error) {
      setChatHistory(prev => [...prev, { role: 'ai', text: "Maaf, something went wrong. Please try again." }]);
    } finally {
      setIsLoading(false);
    }
  };

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return (
          <div className="space-y-6 animate-in fade-in duration-500">
            <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-slate-900">Selamat Pagi, Donor</h1>
                <p className="text-slate-500">Your contributions are reshaping lives in Malaysia.</p>
              </div>
              <div className="flex gap-2">
                <div className="relative">
                   <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                   <input 
                    type="text" 
                    placeholder="Track Receipt (e.g. KC-88)" 
                    className="pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                    value={trackingId}
                    onChange={(e) => setTrackingId(e.target.value)}
                   />
                </div>
                <button className="flex items-center gap-2 bg-emerald-600 text-white px-4 py-2 rounded-lg hover:bg-emerald-700 transition font-medium text-sm shadow-sm">
                  <Heart className="w-4 h-4" /> Quick Donate
                </button>
              </div>
            </header>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {IMPACT_STATS.map((stat, i) => (
                <div key={i} className="bg-white p-6 rounded-xl shadow-sm border border-slate-100 flex flex-col items-center text-center">
                  <span className={`text-3xl font-bold ${stat.color}`}>{stat.value}</span>
                  <span className="text-sm text-slate-500 font-medium uppercase tracking-wider mt-1">{stat.label}</span>
                </div>
              ))}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-100">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-lg font-semibold flex items-center gap-2">
                    <AlertCircle className="w-5 h-5 text-red-500" /> Urgent Needs
                  </h2>
                  <button className="text-emerald-600 text-sm font-medium hover:underline">View All Map</button>
                </div>
                <div className="space-y-4">
                  {MALAYSIA_NEEDS.filter(n => n.urgency === 'Critical').map((need) => (
                    <div key={need.id} className="flex items-center gap-4 p-4 rounded-lg bg-red-50 border border-red-100 group cursor-pointer hover:bg-red-100 transition">
                      <div className="bg-red-500 text-white p-2 rounded-lg">
                        <MapPin className="w-5 h-5" />
                      </div>
                      <div className="flex-1">
                        <h3 className="font-semibold text-slate-900">{need.state}: {need.area}</h3>
                        <p className="text-sm text-slate-600">{need.need}</p>
                      </div>
                      <div className="text-right">
                        <span className="text-xs font-bold bg-red-200 text-red-800 px-2 py-1 rounded">Score: {need.score}</span>
                        <div className="flex items-center text-red-600 text-xs mt-1 font-bold">
                          URGENT <ChevronRight className="w-3 h-3 ml-1" />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* NEW Individual Impact Tracker */}
              <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-100">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-lg font-semibold flex items-center gap-2 text-slate-800">
                    <TrendingUp className="w-5 h-5 text-emerald-600" /> Your Impact Journey
                  </h2>
                  <span className="text-[10px] font-bold bg-emerald-100 text-emerald-700 px-2 py-1 rounded uppercase">Live Status</span>
                </div>
                
                <div className="mb-4 p-3 bg-slate-50 rounded-lg border border-slate-100 flex justify-between items-center">
                  <div>
                    <p className="text-[10px] text-slate-400 font-bold uppercase">Last Receipt</p>
                    <p className="text-sm font-bold text-slate-700">{DONATION_JOURNEY.id}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-[10px] text-slate-400 font-bold uppercase">Target</p>
                    <p className="text-sm font-bold text-emerald-600">{DONATION_JOURNEY.target}</p>
                  </div>
                </div>

                <div className="space-y-6 relative ml-4">
                  {/* Vertical Line */}
                  <div className="absolute left-[7px] top-2 bottom-2 w-[2px] bg-slate-100"></div>

                  {DONATION_JOURNEY.steps.map((step, idx) => (
                    <div key={idx} className="relative pl-8">
                      {/* Node Dot */}
                      <div className={`absolute left-0 top-1.5 w-4 h-4 rounded-full border-2 ${
                        step.status === 'complete' ? 'bg-emerald-500 border-emerald-500' : 
                        step.status === 'active' ? 'bg-white border-emerald-500 animate-pulse' : 
                        'bg-white border-slate-200'
                      } z-10 flex items-center justify-center`}>
                        {step.status === 'complete' && <CheckCircle2 className="w-3 h-3 text-white" />}
                      </div>
                      
                      <div className="flex justify-between items-start">
                        <div>
                          <h4 className={`text-sm font-bold ${step.status === 'pending' ? 'text-slate-400' : 'text-slate-800'}`}>
                            {step.label}
                          </h4>
                          {step.detail && <p className="text-xs text-slate-500 mt-0.5">{step.detail}</p>}
                        </div>
                        <span className="text-[10px] font-medium text-slate-400">{step.date}</span>
                      </div>
                    </div>
                  ))}
                </div>

                <div className="mt-8 flex items-center gap-3 p-4 bg-emerald-50 rounded-xl border border-emerald-100">
                   <div className="bg-emerald-600 text-white p-2 rounded-lg">
                      <Heart className="w-4 h-4" />
                   </div>
                   <div className="flex-1">
                      <p className="text-xs font-bold text-emerald-800">Your RM150 provided 5 warm meals.</p>
                      <p className="text-[10px] text-emerald-600">Distribution at Madrasah Al-Ikhlas, Kelantan.</p>
                   </div>
                   <button className="text-xs font-bold text-emerald-700 underline">Photo Evidence</button>
                </div>
              </div>
            </div>
          </div>
        );
      case 'advisor':
        return (
          <div className="flex flex-col h-[calc(100vh-12rem)] max-w-4xl mx-auto bg-white rounded-2xl shadow-xl overflow-hidden border border-slate-200">
            <div className="bg-emerald-600 p-4 text-white flex items-center gap-3">
              <div className="bg-white/20 p-2 rounded-full">
                <MessageSquare className="w-6 h-6" />
              </div>
              <div>
                <h2 className="font-bold">KitaCare AI Assistant</h2>
                <p className="text-xs text-emerald-100">Online & Ready to help Malaysia</p>
              </div>
            </div>
            
            <div className="flex-1 overflow-y-auto p-6 space-y-4">
              {chatHistory.map((msg, i) => (
                <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[80%] p-4 rounded-2xl ${
                    msg.role === 'user' 
                      ? 'bg-emerald-600 text-white rounded-tr-none shadow-md' 
                      : 'bg-slate-100 text-slate-800 rounded-tl-none border border-slate-200 shadow-sm'
                  }`}>
                    <p className="text-sm whitespace-pre-wrap">{msg.text}</p>
                  </div>
                </div>
              ))}
              {isLoading && (
                <div className="flex justify-start">
                  <div className="bg-slate-100 p-4 rounded-2xl animate-pulse flex gap-2">
                    <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce"></div>
                    <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce delay-100"></div>
                    <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce delay-200"></div>
                  </div>
                </div>
              )}
            </div>

            <div className="p-4 border-t border-slate-100 bg-slate-50">
              <div className="flex gap-2">
                <input 
                  type="text" 
                  value={chatMessage}
                  onChange={(e) => setChatMessage(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
                  placeholder="Ask where to donate RM200 today..."
                  className="flex-1 bg-white border border-slate-300 rounded-xl px-4 py-3 focus:ring-2 focus:ring-emerald-500 focus:outline-none"
                />
                <button 
                  onClick={handleSendMessage}
                  disabled={isLoading}
                  className="bg-emerald-600 text-white p-3 rounded-xl hover:bg-emerald-700 transition disabled:opacity-50 shadow-md"
                >
                  <Send className="w-5 h-5" />
                </button>
              </div>
              <p className="text-[10px] text-slate-400 mt-2 text-center uppercase tracking-widest font-semibold">Powered by Google Gemini 3 Flash</p>
            </div>
          </div>
        );
      case 'map':
        return (
          <div className="space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-100">
              <h2 className="text-xl font-bold mb-4">Live Needs Map — Malaysia</h2>
              <div className="aspect-video bg-slate-200 rounded-lg relative overflow-hidden flex items-center justify-center border-2 border-dashed border-slate-300">
                <div className="text-center space-y-2 p-8 bg-white/50 backdrop-blur rounded-2xl shadow-xl">
                  <MapIcon className="w-12 h-12 text-slate-400 mx-auto" />
                  <p className="text-slate-600 font-medium">Interactive Malaysia Map Loading...</p>
                  <p className="text-xs text-slate-400">Showing 14 States & Federal Territories</p>
                </div>
                {/* Simulated Hotspots */}
                <div className="absolute top-1/4 left-1/3 w-8 h-8 bg-red-500/30 animate-ping rounded-full border-2 border-red-500"></div>
                <div className="absolute bottom-1/2 left-1/4 w-6 h-6 bg-yellow-500/30 animate-pulse rounded-full border-2 border-yellow-500"></div>
                <div className="absolute top-1/2 right-1/4 w-10 h-10 bg-red-600/30 animate-ping rounded-full border-2 border-red-600"></div>
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
               <table className="w-full text-left">
                <thead className="bg-slate-50 text-xs font-bold uppercase text-slate-500">
                  <tr>
                    <th className="px-6 py-4">State</th>
                    <th className="px-6 py-4">Urgent Need</th>
                    <th className="px-6 py-4">Priority Score</th>
                    <th className="px-6 py-4">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {MALAYSIA_NEEDS.map((need) => (
                    <tr key={need.id} className="hover:bg-slate-50 transition">
                      <td className="px-6 py-4">
                        <div className="font-semibold">{need.state}</div>
                        <div className="text-xs text-slate-500">{need.area}</div>
                      </td>
                      <td className="px-6 py-4 text-sm text-slate-600">{need.need}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <div className="w-24 bg-slate-200 h-1.5 rounded-full overflow-hidden">
                            <div 
                              className={`h-full ${need.score > 80 ? 'bg-red-500' : need.score > 50 ? 'bg-yellow-500' : 'bg-emerald-500'}`} 
                              style={{ width: `${need.score}%` }}
                            ></div>
                          </div>
                          <span className="text-xs font-bold text-slate-700">{need.score}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <button className="text-emerald-600 font-semibold text-sm hover:underline">Help Now</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
               </table>
            </div>
          </div>
        );
      case 'guide':
        return (
          <div className="space-y-8 max-w-5xl mx-auto pb-12 animate-in slide-in-from-bottom-4 duration-500">
            <div className="text-center">
              <div className="inline-flex items-center gap-2 bg-emerald-100 text-emerald-700 px-4 py-1 rounded-full text-xs font-bold uppercase tracking-widest mb-4">
                <Smartphone className="w-3 h-3" /> Mobile Developer Track
              </div>
              <h1 className="text-3xl font-extrabold text-slate-900">Flutter Beginner Playbook</h1>
              <p className="text-slate-500 max-w-xl mx-auto mt-2">Build a mobile version of KitaCare AI in 6 steps using Flutter. No prior mobile experience needed.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {FLUTTER_GUIDE.map((item) => (
                <div key={item.step} className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col group hover:shadow-lg transition-all border-l-4 border-l-emerald-600">
                  <div className="p-6">
                    <div className="flex items-center gap-4 mb-4">
                      <div className="bg-emerald-600 text-white p-3 rounded-xl shadow-lg group-hover:scale-110 transition-transform">
                        {item.icon}
                      </div>
                      <div>
                        <span className="text-xs font-bold text-emerald-600 uppercase tracking-widest">Step {item.step}</span>
                        <h3 className="text-xl font-bold text-slate-900">{item.title}</h3>
                      </div>
                    </div>
                    <p className="text-slate-600 text-sm mb-6 leading-relaxed">
                      {item.description}
                    </p>
                    <div className="relative">
                      <div className="absolute top-2 right-2 text-[10px] text-slate-400 font-mono">CODE SNIPPET</div>
                      <pre className="bg-slate-900 text-emerald-400 p-4 rounded-xl overflow-x-auto text-xs font-mono leading-relaxed">
                        <code>{item.code}</code>
                      </pre>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="bg-emerald-900 rounded-3xl p-8 text-white relative overflow-hidden">
               <div className="relative z-10">
                 <h2 className="text-2xl font-bold mb-4">Ready to start?</h2>
                 <p className="text-emerald-100/80 mb-6 max-w-md">Flutter allows you to reach both Android and iOS users with a single codebase. Perfect for Malaysian NGO reach.</p>
                 <a href="https://docs.flutter.dev/get-started" target="_blank" className="inline-flex items-center gap-2 bg-white text-emerald-900 px-8 py-3 rounded-xl font-bold hover:bg-emerald-50 transition shadow-xl">
                   Download Flutter SDK <ChevronRight className="w-4 h-4" />
                 </a>
               </div>
               <div className="absolute top-0 right-0 w-64 h-64 bg-emerald-500/20 blur-3xl -mr-10 -mt-10"></div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="flex min-h-screen">
      {/* Mobile Menu Overlay */}
      {!isSidebarOpen && (
        <button 
          onClick={() => setSidebarOpen(true)}
          className="fixed top-4 left-4 z-50 p-2 bg-white rounded-lg shadow-md lg:hidden"
        >
          <Menu className="w-6 h-6 text-slate-600" />
        </button>
      )}

      {/* Sidebar */}
      <aside className={`fixed inset-y-0 left-0 z-40 w-64 bg-white border-r border-slate-200 transform transition-transform duration-300 ease-in-out lg:translate-x-0 lg:static lg:block ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="p-6 h-full flex flex-col">
          <div className="flex items-center gap-3 mb-10">
            <div className="bg-emerald-600 p-2 rounded-xl text-white">
              <Heart className="w-6 h-6 fill-current" />
            </div>
            <span className="text-xl font-bold tracking-tight">KitaCare <span className="text-emerald-600">AI</span></span>
            <button onClick={() => setSidebarOpen(false)} className="lg:hidden ml-auto">
              <X className="w-5 h-5 text-slate-400" />
            </button>
          </div>

          <nav className="space-y-1 flex-1">
            <NavItem 
              icon={<LayoutDashboard />} 
              label="Dashboard" 
              active={activeTab === 'dashboard'} 
              onClick={() => setActiveTab('dashboard')} 
            />
            <NavItem 
              icon={<MapIcon />} 
              label="Needs Map" 
              active={activeTab === 'map'} 
              onClick={() => setActiveTab('map')} 
            />
            <NavItem 
              icon={<MessageSquare />} 
              label="AI Advisor" 
              active={activeTab === 'advisor'} 
              onClick={() => setActiveTab('advisor')} 
            />
            <NavItem 
              icon={<TrendingUp />} 
              label="Impact Tracking" 
              active={activeTab === 'impact'} 
              onClick={() => setActiveTab('dashboard')} 
            />
            <div className="pt-8 pb-2">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-4">Developers</span>
            </div>
            <NavItem 
              icon={<Smartphone />} 
              label="Flutter Guide" 
              active={activeTab === 'guide'} 
              onClick={() => setActiveTab('guide')} 
              special
            />
          </nav>

          <div className="mt-auto p-4 bg-emerald-50 rounded-2xl border border-emerald-100">
            <div className="flex items-center gap-2 text-emerald-700 font-bold text-sm mb-1">
              <AlertCircle className="w-4 h-4" /> Flood Alert
            </div>
            <p className="text-[11px] text-emerald-600 leading-relaxed font-medium">
              Heavy monsoon expected in Kelantan. AI suggests prioritizing food bank donations.
            </p>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-x-hidden">
        <div className="max-w-7xl mx-auto p-6 md:p-10">
          {renderContent()}
        </div>
      </main>
    </div>
  );
};

const NavItem = ({ icon, label, active, onClick, special = false }: any) => (
  <button 
    onClick={onClick}
    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 group ${
      active 
        ? (special ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200' : 'bg-emerald-50 text-emerald-700') 
        : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
    }`}
  >
    <div className={`${active ? 'text-current' : 'text-slate-400 group-hover:text-slate-600'}`}>
      {React.cloneElement(icon, { size: 20 })}
    </div>
    <span className="font-semibold text-sm">{label}</span>
  </button>
);

const root = createRoot(document.getElementById('root')!);
root.render(<App />);
