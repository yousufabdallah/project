import React, { useState, useEffect } from 'react';
import {
  Users,
  Map,
  Package,
  Truck,
  UserCircle,
  BarChart2,
  Plus,
  Edit2,
  Trash2,
  X,
  Check,
  TruckIcon,
  Box,
  Building2,
  UserPlus,
  UserCog
} from 'lucide-react';
import { supabase, handleSupabaseError } from '../lib/supabase';
import { RegisterEmployeeModal } from './RegisterEmployeeModal';

interface AdminDashboardProps {
  isVisible: boolean;
}

interface Region {
  id: string;
  name: string;
}

interface User {
  id: string;
  email: string;
  is_admin: boolean;
}

interface DriverPermission {
  id: string;
  user_id: string;
  is_approved: boolean;
  email: string;
}

interface DriverSurvey {
  id: string;
  user_id: string;
  user_email: string;
  full_name: string;
  tribe: string;
  age: number;
  car_type: string;
  civil_id: string;
  phone_number: string;
  status: string;
  created_at: string;
}

interface ShippingRequest {
  id: string;
  user_id: string;
  user_email: string;
  pickup_location: string;
  delivery_location: string;
  description: string;
  image_url: string;
  status: string;
  delivery_fee: number;
  order_value: number;
  created_at: string;
  driver_email?: string;
}

interface OfficeAssignment {
  id: string;
  region_id: string;
  user_id: string;
  user_email: string;
}

export function AdminDashboard({ isVisible }: AdminDashboardProps) {
  const [view, setView] = useState<'main' | 'regions' | 'users' | 'drivers' | 'shipments' | 'offices' | 'employees'>('main');
  const [regions, setRegions] = useState<Region[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [driverPermissions, setDriverPermissions] = useState<DriverPermission[]>([]);
  const [driverSurveys, setDriverSurveys] = useState<DriverSurvey[]>([]);
  const [shipments, setShipments] = useState<ShippingRequest[]>([]);
  const [officeAssignments, setOfficeAssignments] = useState<Record<string, string>>({});
  const [newRegion, setNewRegion] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isRegisterModalOpen, setIsRegisterModalOpen] = useState(false);

  useEffect(() => {
    if (view === 'regions' || view === 'offices') {
      fetchRegions();
      if (view === 'offices') {
        fetchUsers();
        fetchOfficeAssignments();
      }
    } else if (view === 'users' || view === 'employees') {
      fetchUsers();
    } else if (view === 'drivers') {
      fetchDriverPermissions();
      fetchDriverSurveys();
    } else if (view === 'shipments') {
      fetchShipments();
    }
  }, [view]);

  const fetchDriverSurveys = async () => {
    try {
      const { data, error } = await supabase
        .from('driver_surveys_view')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setDriverSurveys(data || []);
    } catch (err: any) {
      console.error('Error fetching driver surveys:', err);
      setError(err.message);
    }
  };

  const handleSurveyStatusUpdate = async (userId: string, status: 'approved' | 'rejected') => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('driver_surveys')
        .update({ status })
        .eq('user_id', userId);

      if (error) throw error;

      // If approved, also approve driver permission
      if (status === 'approved') {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) throw new Error('Not authenticated');

        await supabase
          .from('driver_permissions')
          .update({
            is_approved: true,
            approved_by: user.id,
            approved_at: new Date().toISOString()
          })
          .eq('user_id', userId);
      }

      fetchDriverSurveys();
      fetchDriverPermissions();
    } catch (err: any) {
      console.error('Error updating survey status:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchOfficeAssignments = async () => {
    try {
      const { data, error } = await supabase
        .from('office_assignments_view')
        .select('*');

      if (error) throw error;

      const assignments: Record<string, string> = {};
      data?.forEach(assignment => {
        assignments[assignment.region_id] = assignment.user_id;
      });
      setOfficeAssignments(assignments);
    } catch (err: any) {
      console.error('Error fetching office assignments:', err);
      setError(err.message);
    }
  };

  const handleAssignOffice = async (regionId: string, userId: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .rpc('assign_office_staff', {
          p_region_id: regionId,
          p_user_id: userId
        });

      if (error) throw error;

      setOfficeAssignments(prev => ({
        ...prev,
        [regionId]: userId
      }));

      setError('تم تعيين موظف المكتب بنجاح');
      setTimeout(() => setError(''), 3000);
    } catch (err: any) {
      console.error('Error assigning office staff:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchShipments = async () => {
    try {
      const { data, error } = await supabase
        .from('shipping_requests_with_users')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setShipments(data || []);
    } catch (err: any) {
      console.error('Error fetching shipments:', err);
      setError(err.message);
    }
  };

  const fetchRegions = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('regions')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setRegions(data || []);
    } catch (err: any) {
      const handledError = handleSupabaseError(err);
      console.error('Error fetching regions:', handledError);
      setError(handledError.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('user_roles_view')
        .select('id, email, is_admin');
      
      if (error) throw error;
      setUsers(data || []);
    } catch (err: any) {
      const handledError = handleSupabaseError(err);
      console.error('Error fetching users:', handledError);
      setError(handledError.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchDriverPermissions = async () => {
    try {
      const { data, error } = await supabase
        .from('driver_permissions_view')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      const formattedData = data.map(permission => ({
        id: permission.id,
        user_id: permission.user_id,
        is_approved: permission.is_approved,
        email: permission.user_email
      }));

      setDriverPermissions(formattedData);
    } catch (err: any) {
      console.error('Error fetching driver permissions:', err);
      setError(err.message);
    }
  };

  const addRegion = async () => {
    if (!newRegion.trim()) return;
    
    try {
      setLoading(true);
      const { error } = await supabase
        .from('regions')
        .insert([{ name: newRegion.trim() }]);
      
      if (error) throw error;
      
      setNewRegion('');
      fetchRegions();
    } catch (err: any) {
      console.error('Error adding region:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleUserAdmin = async (userId: string, currentStatus: boolean) => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('user_roles')
        .update({ is_admin: !currentStatus })
        .eq('id', userId);
      
      if (error) throw error;
      
      fetchUsers();
    } catch (err: any) {
      console.error('Error updating user role:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleDriverPermission = async (userId: string, currentStatus: boolean) => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase
        .from('driver_permissions')
        .update({
          is_approved: !currentStatus,
          approved_by: user.id,
          approved_at: !currentStatus ? new Date().toISOString() : null
        })
        .eq('user_id', userId);

      if (error) throw error;
      fetchDriverPermissions();
    } catch (err: any) {
      console.error('Error updating driver permission:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const deleteRegion = async (regionId: string) => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('regions')
        .delete()
        .eq('id', regionId);
      
      if (error) throw error;
      
      fetchRegions();
    } catch (err: any) {
      console.error('Error deleting region:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadgeColor = (status: string) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'in_progress':
        return 'bg-blue-100 text-blue-800';
      case 'delivered':
        return 'bg-green-100 text-green-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending':
        return 'في انتظار سائق';
      case 'in_progress':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status;
    }
  };

  if (!isVisible) return null;

  const renderContent = () => {
    switch (view) {
      case 'employees':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">إدارة الموظفين</h3>
              <div className="flex gap-4">
                <button
                  onClick={() => setIsRegisterModalOpen(true)}
                  className="flex items-center gap-2 bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
                >
                  <UserPlus size={20} />
                  <span>تسجيل موظف جديد</span>
                </button>
                <button
                  onClick={() => setView('main')}
                  className="text-blue-600 hover:text-blue-800"
                >
                  عودة
                </button>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      البريد الإلكتروني
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الصلاحيات
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {users.map((user) => (
                    <tr key={user.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {user.email}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <button
                          onClick={() => toggleUserAdmin(user.id, user.is_admin)}
                          className={`flex items-center gap-2 px-3 py-1 rounded ${
                            user.is_admin
                              ? 'bg-green-100 text-green-800'
                              : 'bg-gray-100 text-gray-800'
                          }`}
                        >
                          {user.is_admin ? (
                            <>
                              <Check size={16} />
                              مدير
                            </>
                          ) : (
                            <>
                              <X size={16} />
                              موظف
                            </>
                          )}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      case 'offices':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">إدارة المكاتب</h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      المنطقة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      موظف المكتب
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إجراءات
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {regions.map((region) => (
                    <tr key={region.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {region.name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <select
                          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                          value={officeAssignments[region.id] || ''}
                          onChange={(e) => handleAssignOffice(region.id, e.target.value)}
                          disabled={loading}
                        >
                          <option value="">اختر موظف</option>
                          {users.map(user => (
                            <option key={user.id} value={user.id}>{user.email}</option>
                          ))}
                        </select>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {officeAssignments[region.id] && (
                          <button
                            onClick={() => handleAssignOffice(region.id, '')}
                            className="text-red-600 hover:text-red-900"
                            disabled={loading}
                          >
                            <X size={20} />
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      case 'shipments':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">إدارة الشحنات</h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      المرسل
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      من
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إلى
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الوصف
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      رسوم التوصيل
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      قيمة الطلب
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      السائق
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الحالة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      التاريخ
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {shipments.map((shipment) => (
                    <tr key={shipment.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.user_email}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.pickup_location}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.delivery_location}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.description}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.delivery_fee.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.order_value.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.driver_email || '-'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${getStatusBadgeColor(shipment.status)}`}>
                          {getStatusText(shipment.status)}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {new Date(shipment.created_at).toLocaleDateString('ar-SA')}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      case 'drivers':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">إدارة السائقين</h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <h4 className="px-6 py-3 text-lg font-semibold bg-gray-50">طلبات التسجيل الجديدة</h4>
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      البريد الإلكتروني
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الاسم الكامل
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      القبيلة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      العمر
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      نوع السيارة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الرقم المدني
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      رقم الهاتف
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الحالة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إجراءات
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {driverSurveys.map((survey) => (
                    <tr key={survey.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.user_email}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.full_name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.tribe}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.age}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.car_type}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.civil_id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {survey.phone_number}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          survey.status === 'approved' ? 'bg-green-100 text-green-800' :
                          survey.status === 'rejected' ? 'bg-red-100 text-red-800' :
                          'bg-yellow-100 text-yellow-800'
                        }`}>
                          {survey.status === 'approved' ? 'مقبول' :
                           survey.status === 'rejected' ? 'مرفوض' :
                           'قيد المراجعة'}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {survey.status === 'pending' && (
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleSurveyStatusUpdate(survey.user_id, 'approved')}
                              className="flex items-center gap-1 px-2 py-1 bg-green-100 text-green-800 rounded hover:bg-green-200"
                            >
                              <Check size={16} />
                              قبول
                            </button>
                            <button
                              onClick={() => handleSurveyStatusUpdate(survey.user_id, 'rejected')}
                              className="flex items-center gap-1 px-2 py-1 bg-red-100 text-red-800 rounded hover:bg-red-200"
                            >
                              <X size={16} />
                              رفض
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden mt-6">
              <h4 className="px-6 py-3 text-lg font-semibold bg-gray-50">السائقون المعتمدون</h4>
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      البريد الإلكتروني
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الحالة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إجراءات
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {driverPermissions.map((permission) => (
                    <tr key={permission.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {permission.email}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          permission.is_approved
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {permission.is_approved ? 'مصرح' : 'غير مصرح'}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <button
                          onClick={() => toggleDriverPermission(permission.user_id, permission.is_approved)}
                          disabled={loading}
                          className={`flex items-center gap-2 px-3 py-1 rounded ${
                            permission.is_approved
                              ? 'bg-red-100 text-red-800 hover:bg-red-200'
                              : 'bg-green-100 text-green-800 hover:bg-green-200'
                          }`}
                        >
                          {permission.is_approved ? (
                            <>
                              <X size={16} />
                              إلغاء التصريح
                            </>
                          ) : (
                            <>
                              <Check size={16} />
                              تصريح
                            </>
                          )}
                        </button>
                      </td>
                     </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      case 'regions':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">إدارة المناطق</h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <div className="flex gap-4 mb-6">
              <input
                type="text"
                value={newRegion}
                onChange={(e) => setNewRegion(e.target.value)}
                placeholder="اسم المنطقة"
                className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
              />
              <button
                onClick={addRegion}
                disabled={loading || !newRegion.trim()}
                className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
              >
                إضافة منطقة
              </button>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      المنطقة
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إجراءات
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {regions.map((region) => (
                    <tr key={region.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {region.name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <button
                          onClick={() => deleteRegion(region.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          <Trash2 size={20} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      default:
        return (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <button
              onClick={() => setView('employees')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-blue-50 hover:bg-blue-100 text-blue-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <UserCog className="h-8 w-8" />
              <span className="text-xl">إدارة الموظفين</span>
            </button>
            <button
              onClick={() => setView('offices')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-green-50 hover:bg-green-100 text-green-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Building2 className="h-8 w-8" />
              <span className="text-xl">إدارة المكاتب</span>
            </button>
            <button
              onClick={() => setView('regions')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-purple-50 hover:bg-purple-100 text-purple-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Map className="h-8 w-8" />
              <span className="text-xl">إدارة المناطق</span>
            </button>
            <button
              onClick={() => setView('drivers')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-yellow-50 hover:bg-yellow-100 text-yellow-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <TruckIcon className="h-8 w-8" />
              <span className="text-xl">إدارة السائقين</span>
            </button>
            <button
              onClick={() => setView('shipments')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-red-50 hover:bg-red-100 text-red-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Box className="h-8 w-8" />
              <span className="text-xl">إدارة الشحنات</span>
            </button>
          </div>
        );
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white shadow-lg rounded-lg p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-6 text-center">
          لوحة تحكم المدير
        </h2>
        
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        {renderContent()}

        <RegisterEmployeeModal
          isOpen={isRegisterModalOpen}
          onClose={() => setIsRegisterModalOpen(false)}
        />
      </div>
    </div>
  );
}