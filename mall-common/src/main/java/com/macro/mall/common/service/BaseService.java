package com.macro.mall.common.service;

import com.github.pagehelper.Page;
import com.github.pagehelper.PageHelper;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 通用Service基类
 * 提供基础的CRUD操作能力，减少代码重复
 * 
 * @param <T> 实体类型
 * @param <ID> 主键类型
 * Created by improvement on 2024
 */
public abstract class BaseService<T, ID> {

    /**
     * 获取Mapper实例，子类需实现此方法
     */
    protected abstract Object getMapper();

    /**
     * 根据ID查询单个对象
     * @param id 主键
     * @return 返回对象
     */
    public abstract T selectByPrimaryKey(ID id);

    /**
     * 查询所有对象
     * @return 对象列表
     */
    public abstract List<T> selectAll();

    /**
     * 分页查询
     * @param pageNum 页码
     * @param pageSize 每页记录数
     * @return 分页结果
     */
    public Page<T> selectByPage(int pageNum, int pageSize) {
        PageHelper.startPage(pageNum, pageSize);
        return (Page<T>) selectAll();
    }

    /**
     * 新增对象
     * @param record 待新增的对象
     * @return 插入成功的记录数
     */
    @Transactional
    public abstract int insert(T record);

    /**
     * 更新对象
     * @param record 待更新的对象
     * @return 更新成功的记录数
     */
    @Transactional
    public abstract int updateByPrimaryKey(T record);

    /**
     * 删除对象
     * @param id 待删除对象的主键
     * @return 删除成功的记录数
     */
    @Transactional
    public abstract int deleteByPrimaryKey(ID id);

    /**
     * 批量删除
     * @param ids 待删除的主键列表
     * @return 删除成功的记录数
     */
    @Transactional
    public int deleteByIds(List<ID> ids) {
        int count = 0;
        for (ID id : ids) {
            count += deleteByPrimaryKey(id);
        }
        return count;
    }

    /**
     * 计算总数
     * @return 总记录数
     */
    public abstract long countAll();
}
