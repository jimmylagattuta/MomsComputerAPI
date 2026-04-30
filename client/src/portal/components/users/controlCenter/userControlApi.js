const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || "";

function getAuthHeaders() {
  const token = localStorage.getItem("portalToken");

  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
}

export async function fetchUserControlCenter(userId) {
  const response = await fetch(
    `${API_BASE_URL}/v1/admin/users/${userId}/control_center`,
    {
      method: "GET",
      headers: getAuthHeaders(),
    }
  );

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.error || "Failed to load user control center");
  }

  return data;
}

export async function updateUserCalls(userId, payload) {
  const response = await fetch(
    `${API_BASE_URL}/v1/admin/users/${userId}/control_calls`,
    {
      method: "PATCH",
      headers: getAuthHeaders(),
      body: JSON.stringify(payload),
    }
  );

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.error || "Failed to update call controls");
  }

  return data;
}