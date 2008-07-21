__author__    = "hongqn <hongqn@gmail.com> subdragon <subdragon@gmail.com>"
__version__   = "0.13.2"
__copyright__ = "Copyright (C) 2008 douban.com"
__license__   = "Apache License 2.0"

cdef extern from "Python.h":
	ctypedef int Py_ssize_t
	int PyString_AsStringAndSize(object obj, char **s, Py_ssize_t *len) except -1
	object PyString_FromStringAndSize(char * v, Py_ssize_t len)
	char *PyString_AsString(object obj) except NULL

cdef extern from "stdlib.h":
	ctypedef unsigned int size_t
	ctypedef unsigned int time_t
	void *malloc(size_t size)
	void free(void *ptr)

cdef extern from "stdint.h":
	ctypedef unsigned short int uint16_t
	ctypedef unsigned int uint32_t
	ctypedef unsigned long long int uint64_t

cdef extern from "libmemcached/memcached.h":
	ctypedef enum memcached_return: 
		MEMCACHED_SUCCESS
		MEMCACHED_FAILURE
		MEMCACHED_HOST_LOOKUP_FAILURE
		MEMCACHED_CONNECTION_FAILURE
		MEMCACHED_CONNECTION_BIND_FAILURE
		MEMCACHED_WRITE_FAILURE
		MEMCACHED_READ_FAILURE
		MEMCACHED_UNKNOWN_READ_FAILURE
		MEMCACHED_PROTOCOL_ERROR
		MEMCACHED_CLIENT_ERROR
		MEMCACHED_SERVER_ERROR
		MEMCACHED_CONNECTION_SOCKET_CREATE_FAILURE
		MEMCACHED_DATA_EXISTS
		MEMCACHED_DATA_DOES_NOT_EXIST
		MEMCACHED_NOTSTORED
		MEMCACHED_STORED
		MEMCACHED_NOTFOUND
		MEMCACHED_MEMORY_ALLOCATION_FAILURE
		MEMCACHED_PARTIAL_READ
		MEMCACHED_SOME_ERRORS
		MEMCACHED_NO_SERVERS
		MEMCACHED_END
		MEMCACHED_DELETED
		MEMCACHED_VALUE
		MEMCACHED_STAT
		MEMCACHED_ERRNO
		MEMCACHED_FAIL_UNIX_SOCKET
		MEMCACHED_NOT_SUPPORTED
		MEMCACHED_NO_KEY_PROVIDED
		MEMCACHED_FETCH_NOTFINISHED
		MEMCACHED_TIMEOUT
		MEMCACHED_BUFFERED
		MEMCACHED_BAD_KEY_PROVIDED
		MEMCACHED_MAXIMUM_RETURN # Always add new error code before

	ctypedef enum memcached_behavior:
		MEMCACHED_BEHAVIOR_NO_BLOCK
		MEMCACHED_BEHAVIOR_TCP_NODELAY
		MEMCACHED_BEHAVIOR_HASH
		MEMCACHED_BEHAVIOR_KETAMA
		MEMCACHED_BEHAVIOR_SOCKET_SEND_SIZE
		MEMCACHED_BEHAVIOR_SOCKET_RECV_SIZE
		MEMCACHED_BEHAVIOR_CACHE_LOOKUPS
		MEMCACHED_BEHAVIOR_SUPPORT_CAS
		MEMCACHED_BEHAVIOR_POLL_TIMEOUT
		MEMCACHED_BEHAVIOR_DISTRIBUTION
		MEMCACHED_BEHAVIOR_BUFFER_REQUESTS
		MEMCACHED_BEHAVIOR_SORT_HOSTS
		MEMCACHED_BEHAVIOR_VERIFY_KEY
		MEMCACHED_BEHAVIOR_CONNECT_TIMEOUT

	ctypedef enum memcached_server_distribution:
		MEMCACHED_DISTRIBUTION_MODULA
		MEMCACHED_DISTRIBUTION_CONSISTENT


	ctypedef enum memcached_hash:
		MEMCACHED_HASH_DEFAULT= 0
		MEMCACHED_HASH_MD5
		MEMCACHED_HASH_CRC
		MEMCACHED_HASH_FNV1_64
		MEMCACHED_HASH_FNV1A_64
		MEMCACHED_HASH_FNV1_32
		MEMCACHED_HASH_FNV1A_32
		MEMCACHED_HASH_KETAMA
		MEMCACHED_HASH_HSIEH
		MEMCACHED_HASH_MURMUR

	cdef enum:
		MEMCACHED_MAX_KEY

	struct memcached_st:
		pass

	struct memcached_server_st:
		pass

	memcached_st *memcached_create(memcached_st *ptr)
	void memcached_free(memcached_st *ptr)
	char *memcached_get(memcached_st *ptr, char *key, size_t key_length,
			size_t *value_length,
			uint32_t *flags,
			memcached_return *error)
	memcached_return memcached_set(memcached_st *ptr, char *key, size_t key_length, 
                               char *value, size_t value_length, 
                               time_t expiration,
                               uint32_t  flags)
	memcached_server_st *memcached_servers_parse(char *server_strings)
	memcached_return memcached_server_push(memcached_st *ptr, memcached_server_st *list)
	memcached_return memcached_increment(memcached_st *ptr, 
			char *key, size_t key_length,
			uint32_t offset,
			uint64_t *value)
	memcached_return memcached_decrement(memcached_st *ptr, 
			char *key, size_t key_length,
			uint32_t offset,
			uint64_t *value)
	memcached_return memcached_delete(memcached_st *ptr, char *key, size_t key_length,
			time_t expiration)
	memcached_return memcached_mget(memcached_st *ptr, 
                                char **keys, size_t *key_length, 
                                unsigned int number_of_keys)
	char *memcached_fetch(memcached_st *ptr, char *key, size_t *key_length, 
                      size_t *value_length, uint32_t *flags, 
                      memcached_return *error)
	memcached_return memcached_behavior_set(memcached_st *ptr, memcached_behavior flag, uint64_t data)
	# notice: the old behavior_set API (before libmemcached 0.17) quote: Incompatible change in memcached_behavior_set() api. We now use a uint64_t, instead of a pointer.
	# memcached_return memcached_behavior_set(memcached_st *ptr, memcached_behavior flag, void *data)
	void memcached_server_list_free(memcached_server_st *ptr)
	memcached_return memcached_append(memcached_st *ptr, 
                                  char *key, size_t key_length,
                                  char *value, size_t value_length, 
                                  time_t expiration,
                                  uint32_t flags)
	memcached_return memcached_prepend(memcached_st *ptr, 
                                   char *key, size_t key_length,
                                   char *value, size_t value_length, 
                                   time_t expiration,
                                   uint32_t flags)


#-----------------------------------------

from cPickle import dumps, loads
from string import join 
from time import strftime

class Error(Exception):
	pass

cdef int _FLAG_PICKLE, _FLAG_INTEGER, _FLAG_LONG
_FLAG_PICKLE = 1<<0
_FLAG_INTEGER = 1<<1
_FLAG_LONG = 1<<2

cdef object _prepare_value(object val, uint32_t *flags):
	cdef uint32_t f
	f = 0

	if isinstance(val, basestring):
		flags[0] = 0
		pass
	elif isinstance(val, int):
		f = f | _FLAG_INTEGER
		val = str(val)
	elif isinstance(val, long):
		f = f | _FLAG_LONG
		val = str(val)
	else:
		f = f | _FLAG_PICKLE
		val = dumps(val, -1)

	flags[0] = f
	return val

cdef object _restore(char *c_val, size_t size, uint32_t flags):
	cdef object val

	val = PyString_FromStringAndSize(c_val, size)

	if flags == 0:
		pass
	elif flags & _FLAG_INTEGER:
		val = int(val)
	elif flags & _FLAG_LONG:
		val = long(val)
	elif flags & _FLAG_PICKLE:
		val = loads(val)

	return val


cdef class Client:
	cdef memcached_st *mc
	cdef int debug
	cdef object log
	cdef int log_threshold

	def __new__(self, servers, int debug=0, log=None, int log_threshold=100000):
		"""
		Create a new Client object with the given list of servers.
		"""
		cdef memcached_return retval
		cdef memcached_server_st *server_mc
		cdef uint64_t set
		cdef memcached_server_distribution distribution

		self.debug = debug
		self.log = log
		self.log_threshold = log_threshold

		self.mc = memcached_create(NULL)
		if not self.mc:
			raise MemoryError

		server_string = ','.join(servers)

		server_mc = memcached_servers_parse(server_string) 
		retval = memcached_server_push(self.mc, server_mc)
		memcached_server_list_free(server_mc)

		# set non blocking set
		set = 1
		memcached_behavior_set(self.mc, MEMCACHED_BEHAVIOR_NO_BLOCK, set)
		# no request buffer
		set = 0
		memcached_behavior_set(self.mc, MEMCACHED_BEHAVIOR_BUFFER_REQUESTS, set)

		set = MEMCACHED_HASH_FNV1A_32
		memcached_behavior_set(self.mc, MEMCACHED_BEHAVIOR_HASH, set)
		distribution = MEMCACHED_DISTRIBUTION_CONSISTENT
		memcached_behavior_set(self.mc, MEMCACHED_BEHAVIOR_DISTRIBUTION, distribution)

	def add_server(self, servers):
		"""
		Add new server list
		"""
		cdef memcached_return retval
		cdef memcached_server_st *server_mc

		server_string = ','.join(servers)
		server_mc = memcached_servers_parse(server_string) 
		retval = memcached_server_push(self.mc, server_mc)
		memcached_server_list_free(server_mc)


	def __dealloc__(self):
		memcached_free(self.mc)
	
	def set(self, key, val, time_t time=0):
		cdef Py_ssize_t key_len, bytes
		cdef char *c_key, *c_val
		cdef uint32_t flags
		cdef memcached_return retval

		PyString_AsStringAndSize(key, &c_key, &key_len)

		# memcached do not support the key whose length is bigger than MEMCACHED_MAX_KEY
		if key_len >= MEMCACHED_MAX_KEY:
			return 0

		val = _prepare_value(val, &flags)
		PyString_AsStringAndSize(val, &c_val, &bytes)

		if self.log is not None and bytes >= self.log_threshold:
			self.log.write("[%s] cmemcached: set %d bytes to %r\n" % (
				strftime("%Y-%m-%d %H:%M:%S"), bytes, key))
			self.log.flush()

		retval = memcached_set(self.mc, c_key, key_len, c_val, bytes, time, flags)

		return (retval == 0)

	def append(self, key, val, time_t time=0):
		cdef Py_ssize_t key_len, bytes
		cdef char *c_key, *c_val
		cdef uint32_t flags
		cdef memcached_return retval

		PyString_AsStringAndSize(key, &c_key, &key_len)

		# memcached do not support the key whose length is bigger than MEMCACHED_MAX_KEY
		if key_len >= MEMCACHED_MAX_KEY:
			return 0

		val = _prepare_value(val, &flags)
		PyString_AsStringAndSize(val, &c_val, &bytes)

		retval = memcached_append(self.mc, c_key, key_len, c_val, bytes, time, flags)

		return (retval == 0)

	def prepend(self, key, val, time_t time=0):
		cdef Py_ssize_t key_len, bytes
		cdef char *c_key, *c_val
		cdef uint32_t flags
		cdef memcached_return retval

		PyString_AsStringAndSize(key, &c_key, &key_len)

		# memcached do not support the key whose length is bigger than MEMCACHED_MAX_KEY
		if key_len >= MEMCACHED_MAX_KEY:
			return 0

		val = _prepare_value(val, &flags)
		PyString_AsStringAndSize(val, &c_val, &bytes)

		retval = memcached_prepend(self.mc, c_key, key_len, c_val, bytes, time, flags)

		return (retval == 0)


	def delete(self, key, time_t time=0):
		cdef Py_ssize_t key_len
		cdef char *c_key
		cdef memcached_return retval

		PyString_AsStringAndSize(key, &c_key, &key_len)
		# memcached do not support the key whose length is bigger than MEMCACHED_MAX_KEY
		if key_len >= MEMCACHED_MAX_KEY:
			return 0

		# memcached_delete return MEMCACHED_SUCCESS(0) on success
		retval = memcached_delete(self.mc, c_key, key_len, time)
		# return true if delete successed, otherwise false
		return (retval == 0)


	def get(self, key):
		cdef char *c_key
		cdef Py_ssize_t key_len
		cdef uint32_t flags
		cdef size_t bytes
		cdef memcached_return rc
		cdef char * c_val

		PyString_AsStringAndSize(key, &c_key, &key_len)

		if key_len > 250:
			return None

		flags = 0
		c_val = memcached_get(self.mc, c_key, key_len, &bytes, &flags, &rc)

		if c_val:
			val = _restore(<char *>c_val, bytes, flags)
			free(c_val)
		else:
			val = None

		return val

	def get_raw(self, key):
		cdef char *c_key
		cdef Py_ssize_t key_len
		cdef uint32_t flags
		cdef size_t bytes
		cdef memcached_return rc
		cdef char * c_val

		PyString_AsStringAndSize(key, &c_key, &key_len)

		if key_len > MEMCACHED_MAX_KEY:
			return None

		flags = 0
		c_val = memcached_get(self.mc, c_key, key_len, &bytes, &flags, &rc)

		if c_val:
			val = _restore(<char *>c_val, bytes, 0)
			free(c_val)
		else:
			val = None

		return val

	def get_multi(self, keys):
		cdef char **ckeys
		cdef Py_ssize_t *ckey_lens

		cdef memcached_return rc
		cdef uint32_t flags

		cdef Py_ssize_t key_len
		cdef int i, nkeys, valid_nkeys, index
		cdef char return_key[MEMCACHED_MAX_KEY]
		cdef size_t return_key_length
		cdef char *return_value
		cdef size_t bytes


		nkeys = len(keys)
		ckeys = <char **>malloc(sizeof(char *) * nkeys)
		ckey_lens = <Py_ssize_t *>malloc(sizeof(Py_ssize_t) * nkeys)

		index = 0
		for i from 0 <= i < nkeys:
			PyString_AsStringAndSize(keys[i], &(ckeys[index]), &(ckey_lens[index]))
			if ckey_lens[index] > 0 and ckey_lens[index] < MEMCACHED_MAX_KEY:
				index = index + 1

		valid_nkeys = index


		rc = memcached_mget(self.mc, ckeys, <size_t *>ckey_lens, valid_nkeys)

		result = {}

		flags = 0
		return_value= memcached_fetch(self.mc, return_key, &return_key_length,
				&bytes, &flags, &rc)
		while return_value != NULL:
			val = _restore(<char *>return_value, bytes, flags)
			key = PyString_FromStringAndSize(return_key, return_key_length)
			result[key] = val
			free(return_value)
			flags = 0
			return_value= memcached_fetch(self.mc, return_key, &return_key_length,
				&bytes, &flags, &rc)

		free(ckeys)
		free(ckey_lens)
		return result

	def get_list(self, keys):
		cdef char **ckeys
		cdef Py_ssize_t *ckey_lens

		cdef memcached_return rc
		cdef uint32_t flags

		cdef Py_ssize_t key_len
		cdef int i, nkeys, valid_nkeys, index
		cdef char return_key[MEMCACHED_MAX_KEY]
		cdef size_t return_key_length
		cdef char *return_value
		cdef size_t bytes

		nkeys = len(keys)
		ckeys = <char **>malloc(sizeof(char *) * nkeys)
		ckey_lens = <Py_ssize_t *>malloc(sizeof(Py_ssize_t) * nkeys)

		index = 0
		for i from 0 <= i < nkeys:
			PyString_AsStringAndSize(keys[i], &(ckeys[index]), &(ckey_lens[index]))
			if ckey_lens[index] > 0 and ckey_lens[index] <= 250:
				index = index + 1

		valid_nkeys = index

		rc = memcached_mget(self.mc, ckeys, <size_t *>ckey_lens, valid_nkeys)

		result = {} 

		flags = 0
		return_value= memcached_fetch(self.mc, return_key, &return_key_length,
				&bytes, &flags, &rc)
		while return_value != NULL:
			val = _restore(<char *>return_value, bytes, flags)
			key = PyString_FromStringAndSize(return_key, return_key_length)
			result[key] = val
			free(return_value)
			flags = 0
			return_value= memcached_fetch(self.mc, return_key, &return_key_length,
				&bytes, &flags, &rc)

		l_result = []

		for i from 0 <= i < nkeys:
			if keys[i] in result:
				l_result.append(result[keys[i]])
			else:
				l_result.append(None)

		free(ckeys)
		free(ckey_lens)
		return l_result


	def incr(self, key, int val=1):
		cdef char *c_key
		cdef Py_ssize_t key_len
		cdef uint64_t new_value

		PyString_AsStringAndSize(key, &c_key, &key_len)
		if key_len > 250:
			return 0
		return memcached_increment(self.mc, c_key, key_len, val, &new_value)

	def decr(self, key, int val=1):
		cdef char *c_key
		cdef Py_ssize_t key_len
		cdef uint64_t new_value

		PyString_AsStringAndSize(key, &c_key, &key_len)
		if key_len > 250:
			return 0
		return memcached_decrement(self.mc, c_key, key_len, val, &new_value)
