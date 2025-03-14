import React, { useState, useEffect } from 'react';
import { AuthModal } from './components/AuthModal';
import { AdminDashboard } from './components/AdminDashboard';
import { UserDashboard } from './components/UserDashboard';
import { OfficeStaffDashboard } from './components/OfficeStaffDashboard';
import { supabase } from './lib/supabase';
import { Truck, Package, Globe, LogIn, UserPlus } from 'lucide-react';

function App() {
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [user, setUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [isOfficeStaff, setIsOfficeStaff] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      if (session?.user) {
        checkUserRole(session.user.id);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      if (session?.user) {
        checkUserRole(session.user.id);
      } else {
        setIsAdmin(false);
        setIsOfficeStaff(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkUserRole = async (userId: string) => {
    try {
      // Check if user is admin
      const { data: roleData, error: roleError } = await supabase
        .from('user_roles')
        .select('is_admin')
        .eq('id', userId)
        .single();

      if (roleError) throw roleError;
      setIsAdmin(!!roleData?.is_admin);

      // Check if user is office staff
      const { data: officeData, error: officeError } = await supabase
        .from('office_assignments')
        .select('id')
        .eq('user_id', userId)
        .single();

      if (officeError && officeError.code !== 'PGRST116') throw officeError;
      setIsOfficeStaff(!!officeData);
    } catch (error) {
      console.error('Error checking user role:', error);
    }
  };

  const handleSignOut = async () => {
    try {
      await supabase.auth.signOut();
      setUser(null);
      setIsAdmin(false);
      setIsOfficeStaff(false);
      window.location.href = '/';
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-4">
              <Truck className="h-8 w-8 text-blue-600" />
              <h1 className="text-2xl font-bold text-gray-900">LogiTech</h1>
            </div>
            <div className="flex space-x-4">
              {user ? (
                <button
                  onClick={handleSignOut}
                  className="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
                >
                  تسجيل خروج
                </button>
              ) : (
                <>
                  <button
                    onClick={() => setIsAuthModalOpen(true)}
                    className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
                  >
                    <LogIn size={20} />
                    <span>تسجيل الدخول</span>
                  </button>
                  <button
                    onClick={() => setIsAuthModalOpen(true)}
                    className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700"
                  >
                    <UserPlus size={20} />
                    <span>إنشاء حساب</span>
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </header>

      {/* Dashboards */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {user && (
          isAdmin ? (
            <AdminDashboard isVisible={true} />
          ) : isOfficeStaff ? (
            <OfficeStaffDashboard userId={user.id} />
          ) : (
            <UserDashboard userId={user.id} />
          )
        )}
      </div>

      {!user && (
        <>
          {/* Hero Section */}
          <div className="relative bg-blue-600 py-24">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
              <h2 className="text-4xl font-extrabold text-white sm:text-5xl">
                حلول لوجستية متكاملة لأعمالك
              </h2>
              <p className="mt-4 text-xl text-blue-100">
                نقدم خدمات لوجستية احترافية تساعد شركتك على النمو والتوسع
              </p>
            </div>
          </div>

          {/* Services Section */}
          <div className="py-24 bg-white">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="text-center">
                <h2 className="text-3xl font-extrabold text-gray-900">خدماتنا</h2>
                <p className="mt-4 text-xl text-gray-600">
                  نقدم مجموعة متكاملة من الخدمات اللوجستية
                </p>
              </div>

              <div className="mt-20 grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-3">
                <div className="bg-white p-6 rounded-lg shadow-lg">
                  <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <Truck className="h-6 w-6 text-blue-600" />
                  </div>
                  <h3 className="mt-4 text-xl font-medium text-gray-900">النقل البري</h3>
                  <p className="mt-2 text-gray-600">
                    خدمات نقل بري شاملة داخل المملكة وخارجها
                  </p>
                </div>

                <div className="bg-white p-6 rounded-lg shadow-lg">
                  <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <Package className="h-6 w-6 text-blue-600" />
                  </div>
                  <h3 className="mt-4 text-xl font-medium text-gray-900">التخزين</h3>
                  <p className="mt-2 text-gray-600">
                    مستودعات حديثة ومؤمنة لتخزين بضائعك
                  </p>
                </div>

                <div className="bg-white p-6 rounded-lg shadow-lg">
                  <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <Globe className="h-6 w-6 text-blue-600" />
                  </div>
                  <h3 className="mt-4 text-xl font-medium text-gray-900">الشحن الدولي</h3>
                  <p className="mt-2 text-gray-600">
                    خدمات شحن دولية لجميع أنحاء العالم
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Stats Section */}
          <div className="bg-blue-600 py-16">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="grid grid-cols-1 gap-8 md:grid-cols-3 text-center">
                <div>
                  <div className="text-4xl font-bold text-white">+1000</div>
                  <div className="mt-2 text-blue-100">عميل راضٍ</div>
                </div>
                <div>
                  <div className="text-4xl font-bold text-white">24/7</div>
                  <div className="mt-2 text-blue-100">دعم متواصل</div>
                </div>
                <div>
                  <div className="text-4xl font-bold text-white">+50</div>
                  <div className="mt-2 text-blue-100">مدينة نخدمها</div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Auth Modal */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
      />
    </div>
  );
}

export default App